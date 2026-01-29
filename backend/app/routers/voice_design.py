"""Voice Design API router."""

import io
import logging

import soundfile as sf
from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

from app.models import VoiceDesignRequest
from app.services.tts_manager import tts_manager

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/voice-design")
async def generate_voice_design(request: VoiceDesignRequest):
    """
    Generate speech using Voice Design mode.
    
    Creates a new voice from a natural language description.
    Uses the 1.7B VoiceDesign model.
    """
    try:
        logger.info(f"Voice Design request: text={request.text[:50]}..., lang={request.language}")
        
        audio, sr = tts_manager.generate_voice_design(
            text=request.text,
            language=request.language,
            instruct=request.voice_description,
        )
        
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
        
    except Exception as e:
        logger.exception("Voice Design generation failed")
        raise HTTPException(status_code=500, detail=str(e))
