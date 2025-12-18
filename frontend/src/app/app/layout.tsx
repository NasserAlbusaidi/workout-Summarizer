import type { Metadata } from "next";

export const metadata: Metadata = {
    title: "Analyze Workout | Interval Matcher",
    description: "Upload your FIT file and compare against your planned workout.",
};

export default function AppLayout({
    children,
}: {
    children: React.ReactNode;
}) {
    return children;
}
