"use client";

import * as React from "react";
import Link from "next/link";
import Image from "next/image";
import { motion } from "framer-motion";
import { ArrowRight, Sparkles, Mic, Users, Zap, Globe2, Clock, Volume2 } from "lucide-react";
import { Button } from "@/components/ui/button";

const modes = [
    {
        title: "Voice Design",
        description:
            "Create entirely new voices from natural language descriptions. Describe the voice you want and let AI bring it to life.",
        iconSrc: "/icons/voice-design.svg",
        href: "/voice-design",
        gradient: "from-violet-500 to-purple-600",
        features: ["Natural language control", "Unlimited creativity", "No reference audio needed"],
    },
    {
        title: "Voice Clone",
        description:
            "Clone any voice from a short audio sample. Upload reference audio and generate new speech in that voice.",
        iconSrc: "/icons/voice-clone.svg",
        href: "/voice-clone",
        gradient: "from-pink-500 to-rose-600",
        features: ["Clone from ~10s audio", "High fidelity output", "Speaker embedding support"],
    },
    {
        title: "Custom Voice",
        description:
            "Use pre-trained premium voices with style instructions. Choose from 9 distinct speakers across multiple languages.",
        iconSrc: "/icons/voice-custom.svg",
        href: "/custom-voice",
        gradient: "from-amber-500 to-orange-600",
        features: ["9 premium speakers", "Style control", "10+ languages supported"],
    },
];

const features = [
    {
        icon: Globe2,
        title: "10+ Languages",
        description: "Chinese, English, Japanese, Korean, and 6 more languages",
    },
    {
        icon: Zap,
        title: "Ultra Fast",
        description: "97ms end-to-end latency for real-time applications",
    },
    {
        icon: Volume2,
        title: "High Fidelity",
        description: "12Hz tokenizer for natural, expressive speech",
    },
    {
        icon: Clock,
        title: "Streaming",
        description: "Progressive generation for long-form content",
    },
];

const container = {
    hidden: { opacity: 0 },
    show: {
        opacity: 1,
        transition: {
            staggerChildren: 0.1,
        },
    },
};

const item = {
    hidden: { opacity: 0, y: 20 },
    show: { opacity: 1, y: 0 },
};

export default function HomePage() {
    return (
        <div className="flex flex-col gap-16 pb-16">
            {/* Hero Section */}
            <section className="relative pt-12 md:pt-24">
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.6 }}
                    className="text-center max-w-4xl mx-auto"
                >
                    <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-primary/10 text-primary text-sm font-medium mb-6">
                        <Sparkles className="h-4 w-4" />
                        <span>Powered by Qwen3-TTS</span>
                    </div>

                    <h1 className="text-4xl md:text-6xl lg:text-7xl font-bold tracking-tight mb-6">
                        Premium AI{" "}
                        <span className="gradient-text">Voice Synthesis</span>
                    </h1>

                    <p className="text-lg md:text-xl text-muted-foreground max-w-2xl mx-auto mb-8">
                        Create stunning voices from descriptions, clone any voice from audio samples,
                        or use premium pre-trained speakers. State-of-the-art quality in 10+ languages.
                    </p>

                    <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
                        <Button asChild size="xl" variant="gradient">
                            <Link href="/voice-design">
                                Get Started
                                <ArrowRight className="ml-2 h-5 w-5" />
                            </Link>
                        </Button>
                        <Button asChild size="xl" variant="outline">
                            <Link href="#modes">
                                Explore Modes
                            </Link>
                        </Button>
                    </div>
                </motion.div>

                {/* Animated gradient orbs */}
                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 -z-10 w-full max-w-3xl aspect-square">
                    <motion.div
                        className="absolute inset-0 rounded-full bg-gradient-to-r from-primary/20 to-accent/20 blur-3xl"
                        animate={{
                            scale: [1, 1.1, 1],
                            rotate: [0, 90, 0],
                        }}
                        transition={{
                            duration: 10,
                            repeat: Infinity,
                            ease: "easeInOut",
                        }}
                    />
                </div>
            </section>

            {/* Features bar */}
            <motion.section
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: 0.3 }}
                className="grid grid-cols-2 md:grid-cols-4 gap-4 max-w-4xl mx-auto w-full"
            >
                {features.map((feature) => (
                    <div
                        key={feature.title}
                        className="flex flex-col items-center text-center p-4 rounded-xl bg-card/50 backdrop-blur border border-border/50"
                    >
                        <feature.icon className="h-6 w-6 text-primary mb-2" />
                        <h3 className="font-semibold text-sm">{feature.title}</h3>
                        <p className="text-xs text-muted-foreground mt-1">
                            {feature.description}
                        </p>
                    </div>
                ))}
            </motion.section>

            {/* Modes Section */}
            <section id="modes" className="scroll-mt-20">
                <motion.div
                    variants={container}
                    initial="hidden"
                    whileInView="show"
                    viewport={{ once: true, margin: "-100px" }}
                    className="grid md:grid-cols-3 gap-6"
                >
                    {modes.map((mode) => (
                        <motion.div key={mode.title} variants={item}>
                            <Link href={mode.href} className="group block h-full">
                                <div className="relative h-full p-6 rounded-2xl bg-card/50 backdrop-blur border border-border/50 transition-all duration-300 hover:border-primary/50 hover:shadow-lg hover:shadow-primary/5 overflow-hidden">
                                    {/* Gradient accent */}
                                    <div
                                        className={`absolute top-0 right-0 w-32 h-32 rounded-full bg-gradient-to-br ${mode.gradient} opacity-10 blur-2xl transition-opacity group-hover:opacity-20`}
                                    />

                                    <div className="relative">
                                        {/* Icon */}
                                        <div className="mb-4">
                                            <Image
                                                src={mode.iconSrc}
                                                alt={`${mode.title} icon`}
                                                width={36}
                                                height={36}
                                                className="h-9 w-9"
                                            />
                                        </div>

                                        {/* Title */}
                                        <h3 className="text-xl font-bold mb-2 group-hover:text-primary transition-colors">
                                            {mode.title}
                                        </h3>

                                        {/* Description */}
                                        <p className="text-muted-foreground text-sm mb-4">
                                            {mode.description}
                                        </p>

                                        {/* Features */}
                                        <ul className="space-y-2 mb-6">
                                            {mode.features.map((feature) => (
                                                <li
                                                    key={feature}
                                                    className="flex items-center gap-2 text-sm text-muted-foreground"
                                                >
                                                    <div className="h-1.5 w-1.5 rounded-full bg-primary" />
                                                    {feature}
                                                </li>
                                            ))}
                                        </ul>

                                        {/* CTA */}
                                        <div className="flex items-center gap-2 text-primary font-medium text-sm group-hover:gap-3 transition-all">
                                            Try {mode.title}
                                            <ArrowRight className="h-4 w-4" />
                                        </div>
                                    </div>
                                </div>
                            </Link>
                        </motion.div>
                    ))}
                </motion.div>
            </section>

            {/* How it works section */}
            <section className="max-w-4xl mx-auto w-full">
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    whileInView={{ opacity: 1, y: 0 }}
                    viewport={{ once: true }}
                    className="text-center mb-12"
                >
                    <h2 className="text-3xl font-bold mb-4">How It Works</h2>
                    <p className="text-muted-foreground">
                        Three powerful modes for any voice synthesis need
                    </p>
                </motion.div>

                <div className="grid md:grid-cols-3 gap-8">
                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        whileInView={{ opacity: 1, y: 0 }}
                        viewport={{ once: true }}
                        transition={{ delay: 0.1 }}
                        className="text-center"
                    >
                        <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center mx-auto mb-4">
                            <span className="text-2xl font-bold text-primary">1</span>
                        </div>
                        <h3 className="font-semibold mb-2">Choose Your Mode</h3>
                        <p className="text-sm text-muted-foreground">
                            Select Voice Design for new voices, Clone for existing voices, or Custom for premium speakers
                        </p>
                    </motion.div>

                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        whileInView={{ opacity: 1, y: 0 }}
                        viewport={{ once: true }}
                        transition={{ delay: 0.2 }}
                        className="text-center"
                    >
                        <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center mx-auto mb-4">
                            <span className="text-2xl font-bold text-primary">2</span>
                        </div>
                        <h3 className="font-semibold mb-2">Enter Your Text</h3>
                        <p className="text-sm text-muted-foreground">
                            Type your text, select language, and optionally add style instructions or voice descriptions
                        </p>
                    </motion.div>

                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        whileInView={{ opacity: 1, y: 0 }}
                        viewport={{ once: true }}
                        transition={{ delay: 0.3 }}
                        className="text-center"
                    >
                        <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center mx-auto mb-4">
                            <span className="text-2xl font-bold text-primary">3</span>
                        </div>
                        <h3 className="font-semibold mb-2">Generate & Download</h3>
                        <p className="text-sm text-muted-foreground">
                            Click generate, listen to your audio with the waveform player, and download as WAV
                        </p>
                    </motion.div>
                </div>
            </section>
        </div>
    );
}
