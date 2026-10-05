import React, { useState, useEffect } from "react";

export const ClaudeCodeTerminal: React.FC = () => {
  const [step, setStep] = useState(0);
  const [cursorBlink, setCursorBlink] = useState(true);

  // Cycling Claude Code tool execution stages
  useEffect(() => {
    const stepInterval = setInterval(() => {
      setStep((prev) => (prev >= 4 ? 0 : prev + 1));
    }, 2500);
    return () => clearInterval(stepInterval);
  }, []);

  // Terminal cursor blinking
  useEffect(() => {
    const cursorInterval = setInterval(() => {
      setCursorBlink((prev) => !prev);
    }, 530);
    return () => clearInterval(cursorInterval);
  }, []);

  return (
    <div className="absolute inset-0 overflow-hidden font-mono text-[14px] leading-[1.65] text-[#b5b4a5] select-none pointer-events-none bg-[#0f0f0c]">
      {/* Top macOS Terminal title bar */}
      <div className="h-9 px-5 bg-[#0b0b08] border-b border-[#202016] flex items-center justify-between text-[12px] text-[#706f60]">
        <div className="flex items-center space-x-3">
          {/* macOS window indicator dots */}
          <div className="flex items-center space-x-1.5 mr-2">
            <div className="w-2.5 h-2.5 rounded-full bg-[#ff5f56]" />
            <div className="w-2.5 h-2.5 rounded-full bg-[#ffbd2e]" />
            <div className="w-2.5 h-2.5 rounded-full bg-[#27c93f]" />
          </div>
          <span className="text-[#deddd2] font-semibold">
            claude
          </span>
          <span className="text-[#454436]">—</span>
          <span className="text-[#888776] font-medium">~/Development/floating-ayah (main*)</span>
        </div>
        <div className="flex items-center space-x-3 text-[12px]">
          <span className="text-teal-400 font-semibold">Claude 3.7 Sonnet</span>
          <span className="text-[#454436]">|</span>
          <span className="text-[#7bd88f] font-semibold">49 tests passed</span>
        </div>
      </div>

      {/* Main Terminal Body: High Contrast Deep Dark Background */}
      <div className="p-10 space-y-5 w-full overflow-y-auto no-scrollbar pb-32">
        {/* User Prompt Turn (in English) */}
        <div className="border-l-2 border-teal-400 pl-3.5 py-1 space-y-1 w-full">
          <div className="text-[11px] font-semibold tracking-wider text-teal-400">
            User
          </div>
          <p className="text-[#edece2] text-[15px] font-medium leading-relaxed">
            "Add repeat surah option and insert a 1-second silence pause between surahs. Make sure Surah At-Tawbah starts directly without basmalah."
          </p>
        </div>

        {/* Claude Code Tool Execution Box */}
        <div className="border border-[#202016] p-5 space-y-4 w-full">
          <div className="flex items-center justify-between text-xs text-[#a09f8e] border-b border-[#1c1c13] pb-2.5">
            <div className="flex items-center space-x-2">
              <span className="text-[#deddd2] font-bold text-sm">Claude Code</span>
              <span className="text-[#6d6c5d]">·</span>
              <span className="text-teal-300 font-medium">
                {step === 0 && "Reading codebase & planning"}
                {step === 1 && "Generating silent WAV buffer"}
                {step === 2 && "Editing Sources/FloatingAyah/PlayerStore.swift"}
                {step === 3 && "Running Bash: swift test -c release"}
                {step === 4 && "Building & verifying release package"}
              </span>
            </div>
            <span className="text-[11px] text-[#706f60] font-mono">Cost: $0.04</span>
          </div>

          {/* Action Log Entries (Wide width) */}
          <div className="space-y-2 text-[13px]">
            <div className={`flex items-start gap-2.5 transition-opacity duration-300 ${step >= 0 ? "opacity-100" : "opacity-30"}`}>
              <span className="text-[#7bd88f] font-bold">✓</span>
              <div className="flex-1">
                <span className="text-[#deddd2]">View </span>
                <span className="text-teal-300 font-mono">Sources/FloatingAyah/Quran.swift</span>
                <span className="text-[#888776]"> — added .repeatSurah to PlaybackMode</span>
              </div>
            </div>

            <div className={`flex items-start gap-2.5 transition-opacity duration-300 ${step >= 1 ? "opacity-100" : "opacity-30"}`}>
              <span className={step >= 1 ? "text-[#7bd88f] font-bold" : "text-[#454436]"}>
                {step >= 1 ? "✓" : "○"}
              </span>
              <div className="flex-1">
                <span className="text-[#deddd2]">Created 1-second silence </span>
                <span className="text-teal-300 font-mono">surah-pause.wav</span>
                <span className="text-[#888776]"> inserted into AVQueuePlayer</span>
              </div>
            </div>

            <div className={`flex items-start gap-2.5 transition-opacity duration-300 ${step >= 2 ? "opacity-100" : "opacity-30"}`}>
              <span className={step >= 2 ? "text-[#7bd88f] font-bold" : "text-[#454436]"}>
                {step >= 2 ? "✓" : "○"}
              </span>
              <div className="flex-1">
                <span className="text-[#deddd2]">Special case Surah 9 (At-Tawbah): </span>
                <span className="text-[#f5be7e]">exempted from basmalah queue</span>
              </div>
            </div>
          </div>

          {/* Claude Code Edit Tool Diff Block */}
          <div className="bg-[#0a0a07] border border-[#1a1a12] p-3 text-[13px] font-mono overflow-x-auto text-[#deddd2] w-full">
            <div className="text-[#555446] pb-1">// Edit Sources/FloatingAyah/PlayerStore.swift</div>
            <div className="text-[#706f60]">@@ -74,6 +74,9 @@ func queueNext() &#123;</div>
            <div className="text-[#888776]">     if entry.isLastAyahOfSurah &#123;</div>
            <div className={`text-[#87f59d] bg-[#1d4227]/50 -mx-3 px-3 py-0.5 transition-opacity duration-300 ${step >= 2 ? "opacity-100" : "opacity-30"}`}>
              +        queueOneSecondSilence()
            </div>
            <div className={`text-[#87f59d] bg-[#1d4227]/50 -mx-3 px-3 py-0.5 transition-opacity duration-300 ${step >= 2 ? "opacity-100" : "opacity-30"}`}>
              +        if mode == .repeatSurah &#123; return repeatCurrentSurah() &#125;
            </div>
            <div className="text-[#ff7878] bg-[#4a1d1d]/40 -mx-3 px-3 py-0.5">
              -        advanceImmediatelyToNextSurah()
            </div>
            <div className="text-[#888776]">     &#125;</div>
          </div>
        </div>

        {/* Bash execution */}
        <div className={`space-y-1.5 text-[13px] text-[#deddd2] transition-opacity duration-300 ${step >= 3 ? "opacity-100" : "opacity-30"}`}>
          <div className="flex items-center space-x-2 text-[#deddd2]">
            <span className="text-teal-400 font-bold">$</span>
            <span className="font-semibold text-white">swift test -c release</span>
            <span className="text-[#706f60] text-[11px]">(SurahTransitionTests)</span>
          </div>

          <div className="pl-3.5 border-l border-[#202016] space-y-1 text-[#b5b4a2] text-xs font-mono">
            <div className="flex items-center justify-between pr-4">
              <span className="flex items-center gap-2">
                <span className="text-[#7bd88f]">✓</span>
                <span>testBundledPauseIsExactlyOneSecond</span>
              </span>
              <span className="text-[#706f60]">0.056s</span>
            </div>
            <div className="flex items-center justify-between pr-4">
              <span className="flex items-center gap-2">
                <span className="text-[#7bd88f]">✓</span>
                <span>testRepeatSurahWrapsWithPauseAndNeverAddsBasmalahToTawbah</span>
              </span>
              <span className="text-[#706f60]">0.011s</span>
            </div>
            <div className="flex items-center justify-between pr-4">
              <span className="flex items-center gap-2">
                <span className="text-[#7bd88f]">✓</span>
                <span>testQueueTransitionsSilenceOpeningAyahAndHidesPreviousSurah</span>
              </span>
              <span className="text-[#706f60]">0.464s</span>
            </div>
            <div className="text-[#7bd88f] text-xs pt-1">
              Executed 49 tests, with 3 tests skipped and 0 failures
            </div>
          </div>
        </div>

        {/* AppKit Packaging Command */}
        <div className={`text-[13px] space-y-1 transition-opacity duration-300 ${step >= 4 ? "opacity-100" : "opacity-30"}`}>
          <div className="flex items-center space-x-2 text-[#deddd2]">
            <span className="text-teal-400 font-bold">$</span>
            <span>sh scripts/package-app.sh && sh scripts/verify-package.sh</span>
          </div>
          <div className="text-[#7bd88f] text-xs pl-3.5">
            Built: dist/Floating-Ayah-0.1.2-macos-arm64.dmg (4.9 MB)
          </div>
        </div>

        {/* Claude Code final answer message */}
        <div className="border-l-2 border-[#7bd88f] pl-3.5 py-1 text-[13px] text-[#deddd2] space-y-1 w-full">
          <div className="font-semibold text-white">Floating Ayah v0.1.2 verified:</div>
          <div className="text-[#888776] space-y-0.5 text-xs">
            <div>• Inserted a 1-second silence pause automatically before surah openings.</div>
            <div>• Previous surah verses fade out over 300ms for a clean transition.</div>
            <div>• Surah At-Tawbah skips the basmalah and starts directly at Ayah 1.</div>
          </div>
        </div>

        {/* Claude Code Prompt Input Line */}
        <div className="flex items-center space-x-2 pt-1 text-[#deddd2] text-[13px]">
          <span className="text-teal-400 font-bold">&gt;</span>
          <span className="text-[#888776]">
            {step === 0 && "reading project structure..."}
            {step === 1 && "generating silent audio buffer..."}
            {step === 2 && "applying edits to PlayerStore.swift..."}
            {step === 3 && "running test suite..."}
            {step === 4 && "ready for next instruction"}
          </span>
          <span
            className={`inline-block w-2 h-3.5 bg-teal-400 ml-0.5 ${
              cursorBlink ? "opacity-100" : "opacity-0"
            }`}
          />
        </div>
      </div>

      {/* Bottom Claude Code status bar */}
      <div className="absolute bottom-0 left-0 right-0 h-7 px-5 bg-[#0b0b08] border-t border-[#1c1c13] flex items-center justify-between text-[11px] text-[#555446]">
        <div className="flex items-center space-x-4">
          <span className="text-teal-400">Claude Code v1.0</span>
          <span>|</span>
          <span className="text-[#706f60]">38.2k / 200k tokens</span>
        </div>
        <div className="flex items-center space-x-3 text-[11px] font-mono">
          <span>arm64</span>
          <span className="text-teal-400">0.0% CPU</span>
        </div>
      </div>
    </div>
  );
};
