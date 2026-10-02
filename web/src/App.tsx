import React, { useState, useRef, useEffect } from "react";
import { Download, Volume2, VolumeX, Battery, Wifi } from "lucide-react";
import { ClaudeCodeTerminal } from "./components/ClaudeCodeTerminal";
import { FloatingAyahOverlay } from "./components/FloatingAyahOverlay";
import { AYAT_KURSI } from "./data/ayatKursi";

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

  return (
    <div className="min-h-screen w-full bg-[#0a0a07] text-[#d6d6cd] flex flex-col justify-between py-6 sm:py-8 px-4 sm:px-8 font-sans selection:bg-teal-500/30 selection:text-teal-200">
      {/* Hidden Native Audio Element */}
      <audio ref={audioRef} src={AYAT_KURSI.audio_url} preload="auto" playsInline />

      {/* Top Page Header */}
      <header className="max-w-6xl mx-auto w-full flex items-center justify-between pb-6 select-none">
        <div className="flex items-center space-x-3">
          <img src="/assets/logo-white.png" alt="Floating Ayah" className="w-7 h-7 object-contain" />
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
            href="https://github.com/codeutsman"
            target="_blank"
            rel="noreferrer"
            className="flex items-center space-x-1.5 px-3.5 py-1.5 bg-white text-black hover:bg-[#eae9df] font-semibold text-xs transition-colors rounded-md cursor-pointer"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Download DMG</span>
          </a>
        </div>
      </header>

      {/* Main Container */}
      <main className="max-w-6xl mx-auto w-full flex-1 flex flex-col justify-center my-auto py-2">
        {/* Clean Hero Section (Stripped of AI-slop pill badges) */}
        <section className="text-center max-w-2xl mx-auto mb-6 sm:mb-8 px-4">
          <h1 className="text-2xl sm:text-3xl md:text-4xl font-semibold tracking-tight text-white leading-snug">
            Keep Quran in your <span className="text-teal-300">peripheral vision</span>
            <br />
            while deep in your coding flow.
          </h1>

          <p className="mt-2.5 text-xs sm:text-[13px] text-[#8e8d80] leading-relaxed max-w-lg mx-auto">
            Native macOS menu-bar lyric player synchronized with murattal recitation.
            <br className="hidden sm:inline" />
            Pure Uthmani Arabic text, zero translation noise, and 100% offline.
          </p>
        </section>

        {/* Realistic macOS Desktop Window with Claude Code & Floating Quran Overlay */}
        <div className="relative w-full rounded-xl overflow-hidden border border-[#202016] bg-[#0f0f0c] shadow-2xl shadow-black/95 flex flex-col h-[520px] sm:h-[560px]">
          {/* macOS Desktop Menu Bar Simulation */}
          <div className="h-7 px-4 bg-[#0a0a07] border-b border-[#1c1c13] flex items-center justify-between text-[11px] text-[#706f60] select-none z-30 font-mono">
            {/* Apple Logo & App Title */}
            <div className="flex items-center space-x-4">
              <span className="text-[#dcdbd0]"></span>
              <span className="text-[#dcdbd0]">Terminal</span>
              <span className="hidden sm:inline text-[#555446]">Shell</span>
              <span className="hidden sm:inline text-[#555446]">Edit</span>
              <span className="hidden sm:inline text-[#555446]">View</span>
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
                <img src="/assets/logo-white.png" alt="Floating Ayah" className="w-3.5 h-3.5 object-contain" />
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
        </div>
      </main>

      {/* Minimal Footer */}
      <footer className="max-w-6xl mx-auto w-full pt-6 flex flex-col sm:flex-row items-center justify-between text-xs text-[#555446] select-none gap-2">
        <p>© 2026 Floating Ayah · Free & Open Source under MIT</p>
        <div className="flex items-center space-x-4">
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
