import { z } from "zod";

// Languages supported by Qwen3-TTS
export const LANGUAGES = [
    { value: "Auto", label: "Auto Detect" },
    { value: "Chinese", label: "Chinese" },
    { value: "English", label: "English" },
    { value: "Japanese", label: "Japanese" },
    { value: "Korean", label: "Korean" },
    { value: "French", label: "French" },
    { value: "German", label: "German" },
    { value: "Spanish", label: "Spanish" },
    { value: "Portuguese", label: "Portuguese" },
    { value: "Russian", label: "Russian" },
] as const;

// Speakers for CustomVoice mode
export const SPEAKERS = [
    { value: "Aiden", label: "Aiden", gender: "male", language: "English" },
    { value: "Dylan", label: "Dylan", gender: "male", language: "English" },
    { value: "Eric", label: "Eric", gender: "male", language: "English" },
    { value: "Ono_anna", label: "Ono Anna", gender: "female", language: "Japanese" },
    { value: "Ryan", label: "Ryan", gender: "male", language: "English" },
    { value: "Serena", label: "Serena", gender: "female", language: "English" },
    { value: "Sohee", label: "Sohee", gender: "female", language: "Korean" },
    { value: "Uncle_fu", label: "Uncle Fu", gender: "male", language: "Chinese" },
    { value: "Vivian", label: "Vivian", gender: "female", language: "Chinese" },
] as const;

export const MODEL_SIZES = [
    { value: "0.6B", label: "0.6B (Faster)", description: "Faster generation, good quality" },
    { value: "1.7B", label: "1.7B (Quality)", description: "Best quality, slower generation" },
] as const;

// Zod schemas for validation
export const voiceDesignSchema = z.object({
    text: z.string().min(1, "Text is required").max(5000, "Text is too long"),
    language: z.string().default("Auto"),
    voiceDescription: z.string().min(1, "Voice description is required").max(1000),
});

export const voiceCloneSchema = z.object({
    text: z.string().min(1, "Text is required").max(5000, "Text is too long"),
    language: z.string().default("Auto"),
    modelSize: z.enum(["0.6B", "1.7B"]).default("1.7B"),
    refAudio: z.instanceof(File).optional(),
    refText: z.string().max(1000).optional(),
    xVectorOnly: z.boolean().default(false),
});

export const customVoiceSchema = z.object({
    text: z.string().min(1, "Text is required").max(5000, "Text is too long"),
    language: z.string().default("Auto"),
    speaker: z.string().min(1, "Speaker is required"),
    instruct: z.string().max(500).optional(),
    modelSize: z.enum(["0.6B", "1.7B"]).default("1.7B"),
});

export type VoiceDesignInput = z.infer<typeof voiceDesignSchema>;
export type VoiceCloneInput = z.infer<typeof voiceCloneSchema>;
export type CustomVoiceInput = z.infer<typeof customVoiceSchema>;
