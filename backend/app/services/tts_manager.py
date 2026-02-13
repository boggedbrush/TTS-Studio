"""
TTS Model Manager

Singleton class to manage Qwen3-TTS model loading and inference.
Supports lazy loading and caching of models to minimize memory usage.
"""

import logging
import threading
import time
import gc
from typing import Dict, Optional, Tuple, Union

import torch
import numpy as np

from app.config import MODEL_IDLE_TIMEOUT_S

logger = logging.getLogger(__name__)

# Model IDs
MODEL_IDS = {
    "voice_design": "Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign",
    "base_0.6B": "Qwen/Qwen3-TTS-12Hz-0.6B-Base",
    "base_1.7B": "Qwen/Qwen3-TTS-12Hz-1.7B-Base",
    "custom_0.6B": "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
    "custom_1.7B": "Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice",
}


class TTSManager:
    """Singleton manager for Qwen3-TTS models."""

    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return

        self._models: Dict[str, object] = {}
        self._last_used: Dict[str, float] = {}
        self._model_lock = threading.Lock()
        self._device = self._detect_device()
        self._dtype = torch.bfloat16 if self._device != "cpu" else torch.float32
        self._idle_timeout_s = max(0, MODEL_IDLE_TIMEOUT_S)
        self._cleanup_interval_s = max(30, min(300, self._idle_timeout_s // 6)) if self._idle_timeout_s else 0
        self._stop_cleanup = threading.Event()
        self._cleanup_thread: Optional[threading.Thread] = None
        if self._idle_timeout_s > 0:
            self._cleanup_thread = threading.Thread(
                target=self._cleanup_loop,
                name="tts-model-cleanup",
                daemon=True,
            )
            self._cleanup_thread.start()
        self._initialized = True

        logger.info(
            "TTS Manager initialized. Device: %s, Dtype: %s, idle_timeout_s: %s",
            self._device,
            self._dtype,
            self._idle_timeout_s,
        )

    def _detect_device(self) -> str:
        """Detect the best available compute device."""
        if torch.cuda.is_available():
            return "cuda:0"
        
        # Check for Apple Silicon (MPS)
        if hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            return "mps"
            
        # Check for ROCm (AMD GPU)
        try:
            if hasattr(torch.version, 'hip') and torch.version.hip is not None:
                return "cuda:0"  # ROCm uses cuda device naming
        except Exception:
            pass
        return "cpu"

    def _get_model(self, model_key: str):
        """Get or load a model by key."""
        from app.services.status_manager import status_manager
        
        if model_key not in MODEL_IDS:
            raise ValueError(f"Unknown model key: {model_key}")

        with self._model_lock:
            if model_key not in self._models:
                model_id = MODEL_IDS[model_key]
                logger.info(f"Loading model: {model_id}")
                status_manager.info(f"Loading model: {model_id}")

                try:
                    from qwen_tts import Qwen3TTSModel

                    # Determine attention implementation
                    attn_impl = None
                    if self._device != "cpu":
                        try:
                            import flash_attn
                            attn_impl = "flash_attention_2"
                        except ImportError:
                            attn_impl = "sdpa"  # Fallback to scaled dot product attention

                    load_kwargs = {
                        "device_map": self._device,
                        "attn_implementation": attn_impl,
                    }

                    try:
                        model = Qwen3TTSModel.from_pretrained(
                            model_id,
                            dtype=self._dtype,
                            **load_kwargs,
                        )
                    except TypeError:
                        model = Qwen3TTSModel.from_pretrained(
                            model_id,
                            torch_dtype=self._dtype,
                            **load_kwargs,
                        )
                    self._models[model_key] = model
                    logger.info(f"Model loaded: {model_id}")
                    status_manager.success(f"Model loaded: {model_id}")

                except Exception as e:
                    logger.error(f"Failed to load model {model_id}: {e}")
                    status_manager.error(f"Failed to load model: {e}")
                    raise

            self._touch_model(model_key)
            return self._models[model_key]

    def _touch_model(self, model_key: str):
        """Mark a model as recently used."""
        self._last_used[model_key] = time.monotonic()

    def _clear_device_cache(self):
        """Release framework caches after model unload."""
        gc.collect()
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        elif (
            hasattr(torch, "mps")
            and hasattr(torch.mps, "empty_cache")
            and hasattr(torch.backends, "mps")
            and torch.backends.mps.is_available()
        ):
            torch.mps.empty_cache()

    def _cleanup_loop(self):
        """Background loop that unloads idle models."""
        while not self._stop_cleanup.wait(self._cleanup_interval_s):
            unloaded: list[str] = []
            now = time.monotonic()
            with self._model_lock:
                unloaded = self._unload_idle_models_locked(now)
            if unloaded:
                self._clear_device_cache()
                logger.info(
                    "Unloaded idle models after %ss: %s",
                    self._idle_timeout_s,
                    ", ".join(unloaded),
                )

    def _unload_idle_models_locked(self, now: float) -> list[str]:
        if self._idle_timeout_s <= 0 or not self._models:
            return []

        cutoff = now - self._idle_timeout_s
        stale_keys = [
            key
            for key, last_used in self._last_used.items()
            if key in self._models and last_used <= cutoff
        ]
        for key in stale_keys:
            del self._models[key]
            self._last_used.pop(key, None)
        return stale_keys

    def generate_voice_design(
        self,
        text: str,
        language: str = "Auto",
        instruct: str = "",
    ) -> Tuple[np.ndarray, int]:
        """
        Generate speech using the Voice Design model.

        Args:
            text: Text to synthesize
            language: Target language
            instruct: Voice description/design instruction

        Returns:
            Tuple of (audio_array, sample_rate)
        """
        model = self._get_model("voice_design")
        wavs, sr = model.generate_voice_design(
            text=text,
            language=language if language != "Auto" else "Auto",
            instruct=instruct,
        )
        return wavs[0], sr

    def generate_voice_clone(
        self,
        text: str,
        language: str = "Auto",
        ref_audio: Union[str, Tuple[np.ndarray, int]] = None,
        ref_text: Optional[str] = None,
        x_vector_only: bool = False,
        model_size: str = "1.7B",
    ) -> Tuple[np.ndarray, int]:
        """
        Generate speech by cloning a reference voice.

        Args:
            text: Text to synthesize
            language: Target language
            ref_audio: Reference audio (path, URL, or (array, sr) tuple)
            ref_text: Transcript of reference audio
            x_vector_only: Use only speaker embedding (no transcript needed)
            model_size: "0.6B" or "1.7B"

        Returns:
            Tuple of (audio_array, sample_rate)
        """
        model_key = f"base_{model_size}"
        model = self._get_model(model_key)

        wavs, sr = model.generate_voice_clone(
            text=text,
            language=language if language != "Auto" else "Auto",
            ref_audio=ref_audio,
            ref_text=ref_text if not x_vector_only else None,
            x_vector_only_mode=x_vector_only,
        )
        return wavs[0], sr

    def generate_custom_voice(
        self,
        text: str,
        language: str = "Auto",
        speaker: str = "Vivian",
        instruct: Optional[str] = None,
        model_size: str = "1.7B",
    ) -> Tuple[np.ndarray, int]:
        """
        Generate speech using a pre-trained custom voice.

        Args:
            text: Text to synthesize
            language: Target language
            speaker: Speaker name
            instruct: Optional style instruction
            model_size: "0.6B" or "1.7B"

        Returns:
            Tuple of (audio_array, sample_rate)
        """
        model_key = f"custom_{model_size}"
        model = self._get_model(model_key)

        kwargs = {
            "text": text,
            "language": language if language != "Auto" else "Auto",
            "speaker": speaker,
        }
        if instruct:
            kwargs["instruct"] = instruct

        wavs, sr = model.generate_custom_voice(**kwargs)
        return wavs[0], sr

    def unload_model(self, model_key: str):
        """Unload a specific model to free memory."""
        unloaded = False
        with self._model_lock:
            if model_key in self._models:
                del self._models[model_key]
                self._last_used.pop(model_key, None)
                unloaded = True
        if unloaded:
            self._clear_device_cache()
            logger.info(f"Unloaded model: {model_key}")

    def unload_all(self):
        """Unload all models."""
        had_models = False
        with self._model_lock:
            had_models = bool(self._models)
            self._models.clear()
            self._last_used.clear()
        if had_models:
            self._clear_device_cache()
            logger.info("Unloaded all models")

    def shutdown(self):
        """Stop background cleanup and unload all models."""
        self._stop_cleanup.set()
        if self._cleanup_thread and self._cleanup_thread.is_alive():
            self._cleanup_thread.join(timeout=2.0)
        self.unload_all()


# Global singleton instance
tts_manager = TTSManager()
