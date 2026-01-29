"""Voice Clone API router."""

import io
import logging
import tempfile
from typing import Optional

import numpy as np
import soundfile as sf
from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from fastapi.responses import Response

from app.services.tts_manager import tts_manager

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/voice-clone")
async def generate_voice_clone(
    text: str = Form(...),
    language: str = Form(default="Auto"),
    model_size: str = Form(default="1.7B"),
    ref_text: Optional[str] = Form(default=None),
    x_vector_only: str = Form(default="false"),
    ref_audio: UploadFile = File(...),
):
    """
    Generate speech by cloning a reference voice.
    
    Accepts a reference audio file and optionally its transcript.
    X-Vector Only mode uses just the speaker embedding.
    """
    try:
        logger.info(
            f"Voice Clone request: text={text[:50]}..., lang={language}, "
            f"model={model_size}, x_vector_only={x_vector_only}"
        )
        
        # Parse boolean
        x_vector_only_bool = x_vector_only.lower() in ("true", "1", "yes")
        
        # Validate model size
        if model_size not in ("0.6B", "1.7B"):
            raise HTTPException(status_code=400, detail="Invalid model size")
        
        # Validate ref_text if not x_vector_only
        if not x_vector_only_bool and not ref_text:
            raise HTTPException(
                status_code=400,
                detail="Reference text is required unless x_vector_only is enabled"
            )
        
        # Read and process reference audio
        audio_data = await ref_audio.read()
        
        # Save to temp file and read with soundfile
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            tmp.write(audio_data)
            tmp_path = tmp.name
        
        try:
            ref_audio_array, ref_sr = sf.read(tmp_path)
            
            # Convert to mono if stereo
            if len(ref_audio_array.shape) > 1:
                ref_audio_array = np.mean(ref_audio_array, axis=1)
            
            # Generate cloned speech
            audio, sr = tts_manager.generate_voice_clone(
                text=text,
                language=language,
                ref_audio=(ref_audio_array, ref_sr),
                ref_text=ref_text,
                x_vector_only=x_vector_only_bool,
                model_size=model_size,
            )
        finally:
            import os
            os.unlink(tmp_path)
        
        # Convert to WAV bytes
        buffer = io.BytesIO()
        sf.write(buffer, audio, sr, format="WAV")
        buffer.seek(0)
        
        duration = len(audio) / sr
        
        return Response(
            content=buffer.read(),
            media_type="audio/wav",
            headers={
                "X-Audio-Duration": str(duration),
                "X-Sample-Rate": str(sr),
            },
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Voice Clone generation failed")
        raise HTTPException(status_code=500, detail=str(e))
