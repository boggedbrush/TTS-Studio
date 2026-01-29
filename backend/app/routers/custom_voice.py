"""Custom Voice API router."""

import io
import logging

import soundfile as sf
from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

from app.models import CustomVoiceRequest
from app.services.tts_manager import tts_manager

logger = logging.getLogger(__name__)

router = APIRouter()

# Valid speakers
VALID_SPEAKERS = {
    "Aiden", "Dylan", "Eric", "Ono_anna", "Ryan",
    "Serena", "Sohee", "Uncle_fu", "Vivian"
}


@router.post("/custom-voice")
async def generate_custom_voice(request: CustomVoiceRequest):
    """
    Generate speech using a pre-trained custom voice.
    
    Supports 9 speakers with optional style instructions.
    """
    try:
        logger.info(
            f"Custom Voice request: text={request.text[:50]}..., "
            f"speaker={request.speaker}, lang={request.language}, model={request.model_size}"
        )
        
        # Validate speaker
        if request.speaker not in VALID_SPEAKERS:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid speaker. Must be one of: {', '.join(sorted(VALID_SPEAKERS))}"
            )
        
        # Validate model size
        if request.model_size not in ("0.6B", "1.7B"):
            raise HTTPException(status_code=400, detail="Invalid model size")
        
        audio, sr = tts_manager.generate_custom_voice(
            text=request.text,
            language=request.language,
            speaker=request.speaker,
            instruct=request.instruct,
            model_size=request.model_size,
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
        
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("Custom Voice generation failed")
        raise HTTPException(status_code=500, detail=str(e))
