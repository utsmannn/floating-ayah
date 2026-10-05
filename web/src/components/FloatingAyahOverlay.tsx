import React, { useRef, useEffect, useState } from "react";
import { Play, Pause, RotateCcw, Volume2, VolumeX } from "lucide-react";
import { AYAT_KURSI } from "../data/ayatKursi";

interface FloatingAyahOverlayProps {
  isPlaying: boolean;
  onTogglePlay: () => void;
  onRestart: () => void;
  currentTime: number;
  duration: number;
  onSeek: (time: number) => void;
  isMuted: boolean;
  onToggleMute: () => void;
}

export const FloatingAyahOverlay: React.FC<FloatingAyahOverlayProps> = ({
  isPlaying,
  onTogglePlay,
  onRestart,
  currentTime,
  duration,
  isMuted,
  onToggleMute,
}) => {
  const containerRef = useRef<HTMLDivElement>(null);
  const activeWordRef = useRef<HTMLSpanElement>(null);
  const [isHovered, setIsHovered] = useState(false);

  // Find active token index based on current time (ms)
  const currentMs = currentTime * 1000;
  const activeTokenIndex = AYAT_KURSI.tokens.findIndex(
    (t) =>
      t.is_spoken &&
      t.start_ms !== null &&
      t.end_ms !== null &&
      currentMs >= t.start_ms &&
      currentMs <= t.end_ms
  );

  let displayIndex = activeTokenIndex;
  if (displayIndex === -1 && currentMs > 0) {
    for (let i = AYAT_KURSI.tokens.length - 1; i >= 0; i--) {
      const t = AYAT_KURSI.tokens[i];
      if (t && t.is_spoken && t.start_ms !== null && currentMs >= t.start_ms) {
        displayIndex = i;
        break;
      }
    }
  }

  // Smoothly scroll the container to keep active word vertically centered (AppKit LyricsScrollView replica)
  useEffect(() => {
    if (activeWordRef.current && containerRef.current) {
      const container = containerRef.current;
      const word = activeWordRef.current;
      const containerRect = container.getBoundingClientRect();
      const wordRect = word.getBoundingClientRect();

      // Rectangles include the desktop preview's transform; scroll offsets do not.
      const scale = containerRect.height / container.offsetHeight || 1;
      const offsetTop = (wordRect.top - containerRect.top) / scale + container.scrollTop;
      const targetScroll = offsetTop - container.clientHeight / 2 + wordRect.height / (2 * scale);

      container.scrollTo({
        top: Math.max(0, targetScroll),
        behavior: "smooth",
      });
    }
  }, [displayIndex]);

  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`;
  };

  return (
    <div
      className="absolute bottom-8 right-8 z-40 w-[420px] select-none transition-all duration-300 pointer-events-auto"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      <div className="relative group p-1">
        {/* Subtle controls on hover */}
        <div
          className={`flex items-center justify-between px-3 py-1.5 rounded-lg bg-black/60 backdrop-blur-md border border-white/10 mb-2 text-xs transition-opacity duration-200 ${
            isHovered ? "opacity-100" : "opacity-0"
          }`}
        >
          <div className="flex items-center space-x-2">
            <button
              onClick={(e) => {
                e.stopPropagation();
                onTogglePlay();
              }}
              className="p-1 rounded hover:bg-white/10 text-white transition-colors"
              title={isPlaying ? "Pause" : "Play"}
            >
              {isPlaying ? <Pause className="w-3.5 h-3.5 fill-current" /> : <Play className="w-3.5 h-3.5 fill-current ml-0.5" />}
            </button>

            <button
              onClick={(e) => {
                e.stopPropagation();
                onRestart();
              }}
              className="p-1 rounded hover:bg-white/10 text-neutral-400 hover:text-neutral-200 transition-colors"
              title="Restart"
            >
              <RotateCcw className="w-3 h-3" />
            </button>

            <button
              onClick={(e) => {
                e.stopPropagation();
                onToggleMute();
              }}
              className="p-1 rounded hover:bg-white/10 text-neutral-400 hover:text-neutral-200 transition-colors"
              title={isMuted ? "Unmute" : "Mute"}
            >
              {isMuted ? <VolumeX className="w-3 h-3 text-red-400" /> : <Volume2 className="w-3 h-3 text-white" />}
            </button>

            <span className="text-[11px] font-mono text-neutral-400">
              {formatTime(currentTime)} / {formatTime(duration || 51.59)}
            </span>
          </div>

          <div className="flex items-center space-x-2 text-[11px] text-neutral-300 font-mono">
            <span>Mishary Rashid · 2:255</span>
          </div>
        </div>

        {/* 
          Floating Quran Viewport:
          Exact 1:1 replica of PanelView.swift and screenshot:
          - font: Amiri Quran
          - color: pure white with drop shadow
          - top and bottom non-active ayahs have a deep smooth fade out (opacity 0.42 to 0.1)
          - mask-radial-fade provides smooth gradient feathering so text never cuts abruptly
          - active timed word: translucent background box (bg-white/20) + solid white underline!
        */}
        <div
          ref={containerRef}
          onClick={onTogglePlay}
          className="relative h-[210px] overflow-y-auto no-scrollbar mask-radial-fade cursor-pointer py-10 px-2 text-right transition-colors"
          dir="rtl"
          title="Click to Play / Pause recitation"
        >
          {/* Previous Ayah (Deep feathering fade out on top) */}
          <div
            className="font-quran text-[27px] leading-[2.2] text-white/40 text-justify mb-3 tracking-wide"
            style={{ textShadow: "0 2px 4px rgba(0,0,0,0.85)" }}
          >
            يَٰٓأَيُّهَا ٱلَّذِينَ ءَامَنُوٓا۟ أَنفِقُوا۟ مِمَّا رَزَقْنَٰكُم مِّن قَبْلِ أَن يَأْتِىَ يَوْمٌۭ لَّا بَيْعٌۭ فِيهِ وَلَا خُلَّةٌۭ وَلَا شَفَٰعَةٌۭ ۗ ﴿٢٥٤﴾
          </div>

          {/* Current Ayah: Ayat al-Kursi (2:255) - Crisp, Bright, Beautiful */}
          <div
            className="font-quran text-[31px] leading-[2.2] tracking-wide text-white text-justify"
            style={{
              textShadow: "0 2px 8px rgba(0,0,0,0.95), 0 1px 2px rgba(0,0,0,1)",
            }}
          >
            {AYAT_KURSI.tokens.map((item, idx) => {
              const isActive = idx === displayIndex;

              return (
                <span
                  key={idx}
                  ref={isActive ? activeWordRef : null}
                  className={`relative inline-block px-1 -my-0.5 rounded-xs transition-colors duration-150 ${
                    isActive
                      ? "text-white bg-white/20 underline decoration-white decoration-2 underline-offset-6"
                      : "text-white"
                  }`}
                >
                  {item.token}{" "}
                </span>
              );
            })}

            {/* Ayah End Marker ﴿٢٥٥﴾ */}
            <span
              className="inline-block mx-1 font-quran text-white text-[27px]"
              style={{ textShadow: "0 2px 6px rgba(0,0,0,0.9)" }}
            >
              ﴿٢٥٥﴾
            </span>
          </div>

          {/* Next Ayah (Deep feathering fade out on bottom) */}
          <div
            className="font-quran text-[27px] leading-[2.2] text-white/35 text-justify mt-3 tracking-wide"
            style={{ textShadow: "0 2px 4px rgba(0,0,0,0.85)" }}
          >
            لَآ إِكْرَاهَ فِى ٱلدِّينِ ۖ قَد تَّبَيَّنَ ٱلرُّشْدُ مِنَ ٱلْغَىِّ ۚ فَمَن يَكْفُرْ بِٱلطَّٰغُوتِ وَيُؤْمِنۢ بِٱللَّهِ ﴿٢٥٦﴾
          </div>
        </div>
      </div>
    </div>
  );
};
