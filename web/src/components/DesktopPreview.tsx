import { useLayoutEffect, useRef, useState } from "react";
import type { ReactNode } from "react";

const WIDTH = 1152;
const HEIGHT = 560;

/** Keep the entire desktop scene intact, including its transparent overlay. */
export function DesktopPreview({ children }: { children: ReactNode }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);

  useLayoutEffect(() => {
    const container = containerRef.current;
    if (!container) return;
    const resize = () => setScale(Math.min(1, container.clientWidth / WIDTH));
    resize();
    const observer = new ResizeObserver(resize);
    observer.observe(container);
    return () => observer.disconnect();
  }, []);

  return (
    <div ref={containerRef} className="w-full min-w-0" data-desktop-preview
         style={{ height: HEIGHT * scale }}>
      <div className="relative rounded-xl overflow-hidden border border-[#202016] bg-[#0f0f0c] shadow-2xl shadow-black/95 flex flex-col"
           data-desktop-scene
           style={{ width: WIDTH, height: HEIGHT, transform: `scale(${scale})`, transformOrigin: "top left" }}>
        {children}
      </div>
    </div>
  );
}
