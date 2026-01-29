"""Pydantic models for API requests and responses."""

from typing import Optional, Literal
from pydantic import BaseModel, Field


class VoiceDesignRequest(BaseModel):
    """Request model for voice design generation."""
    text: str = Field(..., min_length=1, max_length=5000, description="Text to synthesize")
    language: str = Field(default="Auto", description="Target language")
    voice_description: str = Field(..., min_length=1, max_length=1000, description="Voice design description")


class VoiceCloneRequest(BaseModel):
    """Request model for voice clone generation (JSON body, file uploaded separately)."""
    text: str = Field(..., min_length=1, max_length=5000, description="Text to synthesize")
    language: str = Field(default="Auto", description="Target language")
    model_size: Literal["0.6B", "1.7B"] = Field(default="1.7B", description="Model size")
    ref_text: Optional[str] = Field(default=None, max_length=1000, description="Reference audio transcript")
    x_vector_only: bool = Field(default=False, description="Use only speaker embedding")


class CustomVoiceRequest(BaseModel):
    """Request model for custom voice generation."""
    text: str = Field(..., min_length=1, max_length=5000, description="Text to synthesize")
    language: str = Field(default="Auto", description="Target language")
    speaker: str = Field(..., description="Speaker name")
    instruct: Optional[str] = Field(default=None, max_length=500, description="Style instruction")
    model_size: Literal["0.6B", "1.7B"] = Field(default="1.7B", description="Model size")


class GenerationResponse(BaseModel):
    """Response metadata for audio generation."""
    success: bool
    duration: float
    sample_rate: int
    message: Optional[str] = None
