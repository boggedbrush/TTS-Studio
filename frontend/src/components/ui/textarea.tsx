import * as React from "react";
import { cn } from "@/lib/utils";

export interface TextareaProps
    extends React.TextareaHTMLAttributes<HTMLTextAreaElement> {
    showCount?: boolean;
    maxLength?: number;
}

const Textarea = React.forwardRef<HTMLTextAreaElement, TextareaProps>(
    ({ className, showCount, maxLength, value, ...props }, ref) => {
        const charCount = typeof value === "string" ? value.length : 0;

        return (
            <div className="relative">
                <textarea
                    className={cn(
                        "flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 resize-none",
                        className
                    )}
                    ref={ref}
                    value={value}
                    maxLength={maxLength}
                    {...props}
                />
                {showCount && maxLength && (
                    <div
                        className={cn(
                            "absolute bottom-2 right-2 text-xs text-muted-foreground",
                            charCount > maxLength * 0.9 && "text-amber-500",
                            charCount >= maxLength && "text-destructive"
                        )}
                    >
                        {charCount}/{maxLength}
                    </div>
                )}
            </div>
        );
    }
);
Textarea.displayName = "Textarea";

export { Textarea };
