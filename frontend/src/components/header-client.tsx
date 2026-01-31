"use client";

import * as React from "react";
import { Header } from "@/components/header";

export function HeaderClient() {
    const [mounted, setMounted] = React.useState(false);

    React.useEffect(() => {
        setMounted(true);
    }, []);

    if (!mounted) return null;

    return <Header />;
}
