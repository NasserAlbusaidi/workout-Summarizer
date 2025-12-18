"use client";

import Link from "next/link";

export default function LandingPage() {
    return (
        <div className="min-h-screen bg-black text-white">
            {/* Navigation */}
            <nav className="border-b border-zinc-800 px-6 py-4">
                <div className="max-w-6xl mx-auto flex items-center justify-between">
                    <h1 className="text-xl font-bold tracking-tight">
                        <span className="text-cyan-400">⚡</span> Interval Matcher
                    </h1>
                    <div className="flex items-center gap-6">
                        <a href="#features" className="text-sm text-zinc-400 hover:text-white transition-colors">
                            Features
                        </a>
                        <a href="#pricing" className="text-sm text-zinc-400 hover:text-white transition-colors">
                            Pricing
                        </a>
                        <Link
                            href="/app"
                            className="text-sm font-medium bg-cyan-500 text-black px-4 py-2 rounded-full hover:bg-cyan-400 transition-colors"
                        >
                            Launch App
                        </Link>
                    </div>
                </div>
            </nav>

            {/* Hero Section */}
            <section className="px-6 py-24 md:py-32">
                <div className="max-w-4xl mx-auto text-center">
                    <div className="inline-block mb-6 px-4 py-1.5 bg-zinc-900 rounded-full border border-zinc-800">
                        <span className="text-xs font-medium text-cyan-400 uppercase tracking-widest">
                            Privacy-First • Zero Data Stored
                        </span>
                    </div>

                    <h1 className="text-4xl md:text-6xl font-bold tracking-tight leading-tight mb-6">
                        Match Your{" "}
                        <span className="text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-blue-500">
                            Planned Workouts
                        </span>
                        <br />
                        With Reality
                    </h1>

                    <p className="text-lg md:text-xl text-zinc-400 max-w-2xl mx-auto mb-10">
                        Compare your intervals.icu training plan with actual FIT file data.
                        See exactly how you performed against each planned interval.
                    </p>

                    <div className="flex flex-col sm:flex-row gap-4 justify-center">
                        <Link
                            href="/app"
                            className="px-8 py-4 bg-gradient-to-r from-cyan-500 to-blue-600 text-black font-bold rounded-lg uppercase tracking-wider hover:from-cyan-400 hover:to-blue-500 transition-all"
                        >
                            🚀 Try It Free
                        </Link>
                        <a
                            href="#features"
                            className="px-8 py-4 border border-zinc-700 rounded-lg font-medium hover:bg-zinc-900 transition-colors"
                        >
                            Learn More
                        </a>
                    </div>
                </div>
            </section>

            {/* Supported Sports */}
            <section className="px-6 py-16 border-t border-zinc-800">
                <div className="max-w-4xl mx-auto">
                    <p className="text-center text-sm text-zinc-500 uppercase tracking-widest mb-8">
                        Works with all major sports
                    </p>
                    <div className="flex justify-center gap-12 md:gap-20">
                        <div className="text-center">
                            <span className="text-4xl">🏃</span>
                            <p className="mt-2 text-sm text-zinc-400">Running</p>
                        </div>
                        <div className="text-center">
                            <span className="text-4xl">🚴</span>
                            <p className="mt-2 text-sm text-zinc-400">Cycling</p>
                        </div>
                        <div className="text-center">
                            <span className="text-4xl">🏊</span>
                            <p className="mt-2 text-sm text-zinc-400">Swimming</p>
                        </div>
                    </div>
                </div>
            </section>

            {/* Features */}
            <section id="features" className="px-6 py-24 bg-zinc-900/50">
                <div className="max-w-6xl mx-auto">
                    <h2 className="text-3xl font-bold text-center mb-4">
                        Everything You Need
                    </h2>
                    <p className="text-center text-zinc-400 mb-16 max-w-2xl mx-auto">
                        Powerful analysis tools that respect your privacy
                    </p>

                    <div className="grid md:grid-cols-3 gap-8">
                        <div className="bg-black rounded-xl p-6 border border-zinc-800">
                            <div className="w-12 h-12 bg-cyan-500/10 rounded-lg flex items-center justify-center mb-4">
                                <span className="text-2xl">🔒</span>
                            </div>
                            <h3 className="text-lg font-bold mb-2">Zero Data Storage</h3>
                            <p className="text-sm text-zinc-400">
                                Your files are processed entirely in memory. Nothing is ever stored on our servers.
                            </p>
                        </div>

                        <div className="bg-black rounded-xl p-6 border border-zinc-800">
                            <div className="w-12 h-12 bg-cyan-500/10 rounded-lg flex items-center justify-center mb-4">
                                <span className="text-2xl">📊</span>
                            </div>
                            <h3 className="text-lg font-bold mb-2">Detailed Analysis</h3>
                            <p className="text-sm text-zinc-400">
                                Compare planned vs actual for every interval. HR, pace, power, cadence - all matched.
                            </p>
                        </div>

                        <div className="bg-black rounded-xl p-6 border border-zinc-800">
                            <div className="w-12 h-12 bg-cyan-500/10 rounded-lg flex items-center justify-center mb-4">
                                <span className="text-2xl">⚡</span>
                            </div>
                            <h3 className="text-lg font-bold mb-2">Instant Results</h3>
                            <p className="text-sm text-zinc-400">
                                Get your analysis in seconds. Export as Markdown or PDF for sharing with your coach.
                            </p>
                        </div>

                        <div className="bg-black rounded-xl p-6 border border-zinc-800">
                            <div className="w-12 h-12 bg-cyan-500/10 rounded-lg flex items-center justify-center mb-4">
                                <span className="text-2xl">📱</span>
                            </div>
                            <h3 className="text-lg font-bold mb-2">Works Everywhere</h3>
                            <p className="text-sm text-zinc-400">
                                Use on any device. Desktop, tablet, or phone - same great experience.
                            </p>
                        </div>

                        <div className="bg-black rounded-xl p-6 border border-zinc-800">
                            <div className="w-12 h-12 bg-cyan-500/10 rounded-lg flex items-center justify-center mb-4">
                                <span className="text-2xl">🔄</span>
                            </div>
                            <h3 className="text-lg font-bold mb-2">intervals.icu Format</h3>
                            <p className="text-sm text-zinc-400">
                                Native support for intervals.icu workout syntax. Just paste your plan and go.
                            </p>
                        </div>

                        <div className="bg-black rounded-xl p-6 border border-zinc-800">
                            <div className="w-12 h-12 bg-cyan-500/10 rounded-lg flex items-center justify-center mb-4">
                                <span className="text-2xl">📜</span>
                            </div>
                            <h3 className="text-lg font-bold mb-2">Local History</h3>
                            <p className="text-sm text-zinc-400">
                                Your session history is stored only in your browser. Review past workouts anytime.
                            </p>
                        </div>
                    </div>
                </div>
            </section>

            {/* Pricing */}
            <section id="pricing" className="px-6 py-24">
                <div className="max-w-5xl mx-auto">
                    <h2 className="text-3xl font-bold text-center mb-4">
                        Simple Pricing
                    </h2>
                    <p className="text-center text-zinc-400 mb-16">
                        Start free, upgrade when you need more
                    </p>

                    <div className="grid md:grid-cols-3 gap-6">
                        {/* Free */}
                        <div className="bg-zinc-900 rounded-xl p-6 border border-zinc-800">
                            <div className="mb-6">
                                <h3 className="text-lg font-bold">Free</h3>
                                <p className="text-sm text-zinc-500">For casual athletes</p>
                            </div>
                            <div className="mb-6">
                                <span className="text-4xl font-bold">$0</span>
                                <span className="text-zinc-500">/month</span>
                            </div>
                            <ul className="space-y-3 mb-8 text-sm">
                                <li className="flex items-center gap-2 text-zinc-300">
                                    <span className="text-green-400">✓</span> 3 analyses per day
                                </li>
                                <li className="flex items-center gap-2 text-zinc-300">
                                    <span className="text-green-400">✓</span> All sports supported
                                </li>
                                <li className="flex items-center gap-2 text-zinc-300">
                                    <span className="text-green-400">✓</span> Export to Markdown
                                </li>
                                <li className="flex items-center gap-2 text-zinc-500">
                                    <span className="text-zinc-600">✗</span> PDF export
                                </li>
                            </ul>
                            <Link
                                href="/app"
                                className="block w-full py-3 text-center border border-zinc-700 rounded-lg hover:bg-zinc-800 transition-colors"
                            >
                                Get Started
                            </Link>
                        </div>

                        {/* Pro */}
                        <div className="bg-gradient-to-b from-cyan-500/10 to-transparent rounded-xl p-6 border-2 border-cyan-500 relative">
                            <div className="absolute -top-3 left-1/2 -translate-x-1/2 px-3 py-1 bg-cyan-500 text-black text-xs font-bold rounded-full">
                                POPULAR
                            </div>
                            <div className="mb-6">
                                <h3 className="text-lg font-bold">Pro</h3>
                                <p className="text-sm text-zinc-500">For serious athletes</p>
                            </div>
                            <div className="mb-6">
                                <span className="text-4xl font-bold">$9</span>
                                <span className="text-zinc-500">/month</span>
                            </div>
                            <ul className="space-y-3 mb-8 text-sm">
                                <li className="flex items-center gap-2 text-zinc-300">
                                    <span className="text-green-400">✓</span> 50 analyses per day
                                </li>
                                <li className="flex items-center gap-2 text-zinc-300">
                                    <span className="text-green-400">✓</span> All sports supported
                                </li>
                                <li className="flex items-center gap-2 text-zinc-300">
                                    <span className="text-green-400">✓</span> Export to Markdown & PDF
                                </li>
                                <li className="flex items-center gap-2 text-zinc-300">
                                    <span className="text-green-400">✓</span> Priority support
                                </li>
                            </ul>
                            <button className="block w-full py-3 text-center bg-cyan-500 text-black font-bold rounded-lg hover:bg-cyan-400 transition-colors">
                                Upgrade to Pro
                            </button>
                        </div>

                        {/* Elite */}
                        <div className="bg-zinc-900 rounded-xl p-6 border border-zinc-800">
                            <div className="mb-6">
                                <h3 className="text-lg font-bold">Elite</h3>
                                <p className="text-sm text-zinc-500">For coaches & teams</p>
                            </div>
                            <div className="mb-6">
                                <span className="text-4xl font-bold">$29</span>
                                <span className="text-zinc-500">/month</span>
                            </div>
                            <ul className="space-y-3 mb-8 text-sm">
                                <li className="flex items-center gap-2 text-zinc-300">
                                    <span className="text-green-400">✓</span> Unlimited analyses
                                </li>
                                <li className="flex items-center gap-2 text-zinc-300">
                                    <span className="text-green-400">✓</span> All sports supported
                                </li>
                                <li className="flex items-center gap-2 text-zinc-300">
                                    <span className="text-green-400">✓</span> All export options
                                </li>
                                <li className="flex items-center gap-2 text-zinc-300">
                                    <span className="text-green-400">✓</span> API access
                                </li>
                            </ul>
                            <button className="block w-full py-3 text-center border border-zinc-700 rounded-lg hover:bg-zinc-800 transition-colors">
                                Contact Sales
                            </button>
                        </div>
                    </div>
                </div>
            </section>

            {/* CTA */}
            <section className="px-6 py-24 bg-gradient-to-b from-zinc-900 to-black">
                <div className="max-w-3xl mx-auto text-center">
                    <h2 className="text-3xl font-bold mb-4">
                        Ready to Analyze Your Workouts?
                    </h2>
                    <p className="text-zinc-400 mb-8">
                        Start for free. No credit card required.
                    </p>
                    <Link
                        href="/app"
                        className="inline-block px-8 py-4 bg-gradient-to-r from-cyan-500 to-blue-600 text-black font-bold rounded-lg uppercase tracking-wider hover:from-cyan-400 hover:to-blue-500 transition-all"
                    >
                        🚀 Launch App
                    </Link>
                </div>
            </section>

            {/* Footer */}
            <footer className="border-t border-zinc-800 px-6 py-8">
                <div className="max-w-6xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4">
                    <div className="text-sm text-zinc-500">
                        © 2024 Interval Matcher. Privacy-first workout analysis.
                    </div>
                    <div className="flex gap-6 text-sm text-zinc-500">
                        <a href="#" className="hover:text-white transition-colors">Privacy</a>
                        <a href="#" className="hover:text-white transition-colors">Terms</a>
                        <a href="#" className="hover:text-white transition-colors">Contact</a>
                    </div>
                </div>
            </footer>
        </div>
    );
}
