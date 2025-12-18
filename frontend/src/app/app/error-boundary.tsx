"use client";

import React from "react";

interface ErrorBoundaryProps {
    children: React.ReactNode;
    fallback?: React.ReactNode;
}

interface ErrorBoundaryState {
    hasError: boolean;
    error?: Error;
}

export class ErrorBoundary extends React.Component<ErrorBoundaryProps, ErrorBoundaryState> {
    constructor(props: ErrorBoundaryProps) {
        super(props);
        this.state = { hasError: false };
    }

    static getDerivedStateFromError(error: Error): ErrorBoundaryState {
        return { hasError: true, error };
    }

    componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
        console.error("Error caught by boundary:", error, errorInfo);
    }

    render() {
        if (this.state.hasError) {
            return (
                this.props.fallback || (
                    <div className="p-6 bg-red-900/20 border border-red-500 rounded-xl text-center">
                        <div className="text-4xl mb-4">⚠️</div>
                        <h3 className="text-lg font-bold text-red-400 mb-2">Something went wrong</h3>
                        <p className="text-sm text-zinc-400 mb-4">
                            {this.state.error?.message || "An unexpected error occurred"}
                        </p>
                        <button
                            onClick={() => this.setState({ hasError: false, error: undefined })}
                            className="px-4 py-2 bg-red-500 text-white rounded-lg text-sm font-medium hover:bg-red-400 transition-colors"
                        >
                            Try Again
                        </button>
                    </div>
                )
            );
        }

        return this.props.children;
    }
}

// Wrapper for chart errors
export function ChartErrorBoundary({ children }: { children: React.ReactNode }) {
    return (
        <ErrorBoundary
            fallback={
                <div className="p-4 bg-zinc-800 rounded-xl text-center text-zinc-500">
                    <span className="text-2xl">📊</span>
                    <p className="mt-2 text-sm">Chart failed to load</p>
                </div>
            }
        >
            {children}
        </ErrorBoundary>
    );
}
