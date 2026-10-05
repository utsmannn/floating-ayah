import React, { useState, useRef, useEffect } from "react";
import { Volume2, VolumeX, Battery, Wifi, Terminal, Copy, Check } from "lucide-react";
import { ClaudeCodeTerminal } from "./components/ClaudeCodeTerminal";
import { FloatingAyahOverlay } from "./components/FloatingAyahOverlay";
import { DesktopPreview } from "./components/DesktopPreview";
import { AYAT_KURSI } from "./data/ayatKursi";

const logoUrl = new URL("../assets/logo-white.png", import.meta.url).href;

export const App: React.FC = () => {
  const [playbackTime, setPlaybackTime] = useState(0);
  const [isAudioMuted, setIsAudioMuted] = useState(true);
  const [isUserPaused, setIsUserPaused] = useState(false);
  const duration = AYAT_KURSI.duration_ms / 1000;

  const audioRef = useRef<HTMLAudioElement | null>(null);

  // High-precision clock that drives the word-by-word sync and auto-scroll automatically
  useEffect(() => {
    if (isUserPaused) return;

    const interval = setInterval(() => {
      setPlaybackTime((prev) => {
        const next = prev + 0.1;
        if (next >= duration) {
          if (audioRef.current) {
            audioRef.current.currentTime = 0;
          }
          return 0;
        }
        return next;
      });
    }, 100);

    return () => clearInterval(interval);
  }, [isUserPaused, duration]);

  // Sync HTML5 Audio with simulated time when unmuted
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;

    if (!isAudioMuted && !isUserPaused) {
      audio.currentTime = playbackTime;
      audio.play().catch(() => {});
    } else {
      audio.pause();
    }
  }, [isAudioMuted, isUserPaused]);

  // Spacebar toggle
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable)) {
        return;
      }
      if (e.code === "Space") {
        e.preventDefault();
        togglePlay();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [isUserPaused]);

  const togglePlay = () => {
    setIsUserPaused((prev) => !prev);
  };

  const handleRestart = () => {
    setPlaybackTime(0);
    if (audioRef.current) {
      audioRef.current.currentTime = 0;
    }
    setIsUserPaused(false);
  };

  const handleSeek = (time: number) => {
    setPlaybackTime(time);
    if (audioRef.current) {
      audioRef.current.currentTime = time;
    }
  };

  const toggleMute = () => {
    setIsAudioMuted((prev) => !prev);
  };

  const [copied, setCopied] = useState(false);
  const installCommand = "curl -fsSL https://floating-ayah.kiatkoding.com/install.sh | bash";

  const handleCopyInstall = async () => {
    try {
      await navigator.clipboard.writeText(installCommand);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Fallback
    }
  };

  return (
    <div className="min-h-screen w-full bg-[#0a0a07] text-[#d6d6cd] flex flex-col justify-between py-4 sm:py-6 px-4 sm:px-8 font-sans selection:bg-teal-500/30 selection:text-teal-200">
      {/* Hidden Native Audio Element */}
      <audio ref={audioRef} src={AYAT_KURSI.audio_url} preload="auto" playsInline />

      {/* Top Page Header */}
      <header className="max-w-6xl mx-auto w-full flex flex-wrap items-center justify-between gap-4 pb-4 select-none">
        <div className="flex items-center space-x-3">
          <img src={logoUrl} alt="Floating Ayah" className="w-7 h-7 object-contain" />
          <span className="font-bold text-lg text-white tracking-tight">Floating Ayah</span>
        </div>

        <div className="flex items-center space-x-3">
          <button
            onClick={toggleMute}
            className="flex items-center space-x-2 px-3 py-1.5 text-xs text-[#a09f8e] hover:text-white transition-colors cursor-pointer"
            title={isAudioMuted ? "Click to enable sound" : "Mute audio"}
          >
            {isAudioMuted ? <VolumeX className="w-3.5 h-3.5 text-teal-400" /> : <Volume2 className="w-3.5 h-3.5 text-teal-400" />}
            <span>{isAudioMuted ? "Audio Muted" : "Playing Alafasy"}</span>
          </button>

          <a
            href="https://github.com/utsmannn/floating-ayah"
            target="_blank"
            rel="noreferrer"
            className="flex items-center justify-center w-8 h-8 text-[#a09f8e] hover:text-white hover:bg-white/5 transition-colors rounded-md"
            title="View on GitHub"
            aria-label="Floating Ayah on GitHub"
          >
            <svg viewBox="0 0 24 24" className="w-[18px] h-[18px]" fill="currentColor" aria-hidden="true">
              <path d="M12 .5C5.65.5.5 5.65.5 12c0 5.08 3.29 9.39 7.86 10.91.58.11.79-.25.79-.55v-2.1c-3.2.7-3.87-1.36-3.87-1.36-.52-1.33-1.28-1.69-1.28-1.69-1.05-.71.08-.7.08-.7 1.15.08 1.76 1.19 1.76 1.19 1.03 1.76 2.69 1.25 3.35.96.1-.75.4-1.25.73-1.54-2.55-.29-5.24-1.28-5.24-5.69 0-1.26.45-2.28 1.19-3.09-.12-.29-.52-1.46.11-3.05 0 0 .97-.31 3.17 1.18a11 11 0 0 1 5.77 0c2.2-1.49 3.17-1.18 3.17-1.18.63 1.59.23 2.76.11 3.05.74.81 1.19 1.83 1.19 3.09 0 4.42-2.7 5.4-5.27 5.68.41.36.78 1.06.78 2.14v3.17c0 .31.21.67.8.55A11.5 11.5 0 0 0 23.5 12C23.5 5.65 18.35.5 12 .5z" />
            </svg>
          </a>
        </div>
      </header>

      {/* Main Container */}
      <main className="max-w-6xl mx-auto w-full flex-1 flex flex-col justify-center my-auto py-1">
        {/* Clean Hero Section (Stripped of AI-slop pill badges) */}
        <section className="text-center max-w-2xl mx-auto mb-4 sm:mb-5 px-4">
          <h1 className="text-2xl sm:text-3xl md:text-[34px] font-semibold tracking-tight text-white leading-snug">
            Keep Quran in your <span className="text-teal-300">peripheral vision</span>
            <br />
            while deep in your coding flow.
          </h1>

          <p className="mt-2 text-xs sm:text-[13px] text-[#8e8d80] leading-relaxed max-w-lg mx-auto">
            Native macOS menu-bar lyric player synchronized with murattal recitation.
            <br className="hidden sm:inline" />
            Pure Uthmani Arabic text, zero translation noise, and 100% offline.
          </p>
        </section>

        {/* CLI One-line Installer with Copy CTA */}
        <div className="mb-4 sm:mb-5 flex flex-col items-center justify-center gap-2">
          <div className="flex items-center gap-2 px-3.5 py-2 bg-[#12120e] hover:bg-[#161611] border border-[#24241a] rounded-lg transition-colors max-w-full font-mono text-xs text-[#d6d6cd] group">
            <Terminal className="w-3.5 h-3.5 text-teal-400 shrink-0" />
            <code className="truncate max-w-[280px] sm:max-w-md md:max-w-lg select-all text-[#c8c7bb]">
              {installCommand}
            </code>
            <button
              onClick={handleCopyInstall}
              className="flex items-center gap-1.5 ml-2 px-2.5 py-1 bg-white/5 hover:bg-white/10 active:bg-white/15 text-white rounded border border-white/10 transition-colors cursor-pointer text-[11px] font-sans font-medium shrink-0"
              title="Copy install command"
            >
              {copied ? (
                <>
                  <Check className="w-3 h-3 text-[#7bd88f]" />
                  <span className="text-[#7bd88f]">Copied</span>
                </>
              ) : (
                <>
                  <Copy className="w-3 h-3 text-[#a09f8e]" />
                  <span>Copy</span>
                </>
              )}
            </button>
          </div>
          <p className="text-[11px] text-[#6d6c5c] tracking-tight">
            macOS 13+ · Apple Silicon · No sudo required · Auto-verifies checksum
          </p>
        </div>

        {/* Realistic macOS Desktop Window with Claude Code & Floating Quran Overlay */}
        <DesktopPreview>
          {/* macOS Desktop Menu Bar Simulation */}
          <div className="h-7 px-4 bg-[#0a0a07] border-b border-[#1c1c13] flex items-center justify-between text-[11px] text-[#706f60] select-none z-30 font-mono">
            {/* Apple Logo & App Title */}
            <div className="flex items-center space-x-4">
              <span className="text-[#dcdbd0]"></span>
              <span className="text-[#dcdbd0]">Terminal</span>
              <span className="text-[#555446]">Shell</span>
              <span className="text-[#555446]">Edit</span>
              <span className="text-[#555446]">View</span>
            </div>

            {/* Menu Bar Tray (With Floating Ayah Status Bar Icon!) */}
            <div className="flex items-center space-x-3 text-[#706f60]">
              <span className="text-[#a09f8e]">Claude Code</span>
              <span className="text-[#454436]">·</span>
              
              {/* Floating Ayah Status Bar Icon (Minimal native tray representation, no pill) */}
              <div
                onClick={toggleMute}
                className="flex items-center space-x-1.5 text-[#dcdbd0] hover:text-teal-300 cursor-pointer transition-colors"
                title="Floating Ayah in Menu Bar (Click to toggle sound)"
              >
                <img src={logoUrl} alt="Floating Ayah" className="w-3.5 h-3.5 object-contain" />
                <span className="text-[10px] text-teal-400">2:255</span>
              </div>

              <Wifi className="w-3 h-3" />
              <Battery className="w-3.5 h-3.5" />
              <span>15:55</span>
            </div>
          </div>

          {/* Desktop Wallpaper / Window Interior */}
          <div className="relative flex-1 overflow-hidden flex flex-col">
            {/* Background Layer: Claude Code Terminal View */}
            <ClaudeCodeTerminal />

            {/* Bottom-Right: Native Floating Ayah Transparent Lyric Window (Auto-scrolling with current active word highlight) */}
            <FloatingAyahOverlay
              isPlaying={!isUserPaused}
              onTogglePlay={togglePlay}
              onRestart={handleRestart}
              currentTime={playbackTime}
              duration={duration}
              onSeek={handleSeek}
              isMuted={isAudioMuted}
              onToggleMute={toggleMute}
            />
          </div>
        </DesktopPreview>
      </main>

      {/* Minimal Footer */}
      <footer className="max-w-6xl mx-auto w-full pt-6 flex flex-col sm:flex-row items-center justify-between text-xs text-[#555446] select-none gap-2">
        <p>© 2026 Floating Ayah · Free & Open Source under MIT</p>
        <div className="flex flex-wrap items-center justify-center gap-x-4 gap-y-2">
          <a
            href="https://kiatkoding.com"
            target="_blank"
            rel="noreferrer"
            className="hover:text-white transition-colors"
          >
            By Kiat Koding
          </a>
          <span>·</span>
          <span>Amiri Quran Font</span>
          <span>·</span>
          <span>EveryAyah Audio</span>
        </div>
      </footer>
    </div>
  );
};
export default App;
