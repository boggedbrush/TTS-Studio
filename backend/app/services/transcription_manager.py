"""
Transcription Service Manager

Singleton class to manage Whisper model for automatic speech recognition.
Supports lazy loading and GPU acceleration.
"""

import logging
import threading
import time
import gc
from typing import Optional

import torch
import numpy as np

from app.config import MODEL_IDLE_TIMEOUT_S

logger = logging.getLogger(__name__)


class TranscriptionManager:
    """Singleton manager for Whisper transcription model."""

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

        self._pipeline = None
        self._model_lock = threading.Lock()
        self._device = self._detect_device()
        self._last_used: float | None = None
        self._idle_timeout_s = max(0, MODEL_IDLE_TIMEOUT_S)
        self._cleanup_interval_s = max(30, min(300, self._idle_timeout_s // 6)) if self._idle_timeout_s else 0
        self._stop_cleanup = threading.Event()
        self._cleanup_thread: Optional[threading.Thread] = None
        if self._idle_timeout_s > 0:
            self._cleanup_thread = threading.Thread(
                target=self._cleanup_loop,
                name="transcription-model-cleanup",
                daemon=True,
            )
            self._cleanup_thread.start()
        self._initialized = True

        logger.info(
            "Transcription Manager initialized. Device: %s, idle_timeout_s: %s",
            self._device,
            self._idle_timeout_s,
        )

    def _detect_device(self) -> str:
        """Detect the best available compute device."""
        if torch.cuda.is_available():
            return "cuda:0"
        
        # Check for Apple Silicon (MPS)
        if hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
            return "mps"
            
        return "cpu"

    def _get_pipeline(self):
        """Get or load the Whisper pipeline."""
        from app.services.status_manager import status_manager
        
        with self._model_lock:
            if self._pipeline is None:
                logger.info("Loading Whisper model for transcription...")
                status_manager.info("Loading transcription model...")

                try:
                    from transformers import pipeline

                    # Use whisper-base for good balance of speed and accuracy
                    dtype = torch.float16 if self._device.startswith("cuda") else torch.float32
                    pipeline_kwargs = {
                        "task": "automatic-speech-recognition",
                        "model": "openai/whisper-base",
                        "device": self._device,
                    }

                    try:
                        self._pipeline = pipeline(
                            **pipeline_kwargs,
                            dtype=dtype,
                        )
                    except TypeError:
                        self._pipeline = pipeline(
                            **pipeline_kwargs,
                            torch_dtype=dtype,
                        )
                    
                    logger.info("Whisper model loaded successfully")
                    status_manager.success("Transcription model loaded")

                except Exception as e:
                    logger.error(f"Failed to load Whisper model: {e}")
                    status_manager.error(f"Failed to load transcription model: {e}")
                    raise

            self._last_used = time.monotonic()
            return self._pipeline

    def _clear_device_cache(self):
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

    def _unload_locked(self) -> bool:
        if self._pipeline is None:
            return False
        del self._pipeline
        self._pipeline = None
        self._last_used = None
        return True

    def _cleanup_loop(self):
        while not self._stop_cleanup.wait(self._cleanup_interval_s):
            should_unload = False
            now = time.monotonic()
            with self._model_lock:
                if (
                    self._pipeline is not None
                    and self._last_used is not None
                    and (now - self._last_used) >= self._idle_timeout_s
                ):
                    should_unload = self._unload_locked()
            if should_unload:
                self._clear_device_cache()
                logger.info("Unloaded idle transcription model after %ss", self._idle_timeout_s)

    def transcribe(
        self,
        audio: np.ndarray,
        sample_rate: int,
        language: Optional[str] = None,
    ) -> str:
        """
        Transcribe audio to text.

        Args:
            audio: Audio data as numpy array
            sample_rate: Sample rate of the audio
            language: Optional language hint (ISO 639-1 code, e.g., 'en', 'zh')

        Returns:
            Transcribed text
        """
        from app.services.status_manager import status_manager
        
        pipe = self._get_pipeline()
        
        status_manager.info("Transcribing audio...")
        
        try:
            # Prepare audio input
            audio_input = {"array": audio, "sampling_rate": sample_rate}
            
            # Build generation kwargs
            generate_kwargs = {
                "task": "transcribe",
            }
            if language:
                # Map common language names to codes
                lang_map = {
                    "English": "en",
                    "Chinese": "zh",
                    "Japanese": "ja",
                    "Korean": "ko",
                    "German": "de",
                    "French": "fr",
                    "Russian": "ru",
                    "Portuguese": "pt",
                    "Spanish": "es",
                    "Italian": "it",
                }
                lang_code = lang_map.get(language, language.lower()[:2] if len(language) >= 2 else None)
                if lang_code:
                    generate_kwargs["language"] = lang_code

            # First try a straightforward transcription (most reliable for short clips)
            result = pipe(
                audio_input,
                generate_kwargs=generate_kwargs,
            )

            text = result.get("text", "").strip()

            # If text is empty/too short, fall back to chunked decoding
            if len(text) < 3:
                chunked = pipe(
                    audio_input,
                    chunk_length_s=15,
                    stride_length_s=3,
                    generate_kwargs=generate_kwargs,
                )
                chunk_text = chunked.get("text", "").strip()
                if len(chunk_text) > len(text):
                    text = chunk_text
            
            logger.info(f"Transcription complete: {len(text)} characters")
            status_manager.success("Transcription complete")
            
            return text
            
        except Exception as e:
            logger.error(f"Transcription failed: {e}")
            status_manager.error(f"Transcription failed: {e}")
            raise

    def unload(self):
        """Unload the model to free memory."""
        with self._model_lock:
            unloaded = self._unload_locked()
        if unloaded:
            self._clear_device_cache()
            logger.info("Transcription model unloaded")

    def shutdown(self):
        """Stop background cleanup and unload the model."""
        self._stop_cleanup.set()
        if self._cleanup_thread and self._cleanup_thread.is_alive():
            self._cleanup_thread.join(timeout=2.0)
        self.unload()


# Global singleton instance
transcription_manager = TranscriptionManager()
