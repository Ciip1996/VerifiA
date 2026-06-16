import { useEffect, useRef, useState } from 'react';

interface Props {
  src: string;
  label: string;
  onClose: () => void;
}

export function PhotoLightbox({ src, label, onClose }: Props) {
  const [scale, setScale] = useState(1);
  const imgRef = useRef<HTMLImageElement>(null);

  // Close on Escape key
  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if (e.key === 'Escape') onClose();
    }
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [onClose]);

  // Mouse wheel to zoom
  function onWheel(e: React.WheelEvent) {
    e.preventDefault();
    setScale((s) => Math.min(5, Math.max(0.5, s - e.deltaY * 0.002)));
  }

  function resetZoom() {
    setScale(1);
  }

  return (
    <div
      onClick={onClose}
      style={{
        position: 'fixed', inset: 0, zIndex: 1000,
        background: 'rgba(0,0,0,0.92)',
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
        animation: 'fadeIn 0.18s ease',
      }}
    >
      {/* Top bar */}
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          position: 'absolute', top: 0, left: 0, right: 0, height: 52,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '0 1rem', background: 'rgba(0,0,0,0.6)',
        }}
      >
        <span style={{ fontSize: '0.85rem', color: 'rgba(255,255,255,0.7)', fontWeight: 600 }}>{label}</span>
        <div style={{ display: 'flex', gap: '0.5rem' }}>
          <button
            onClick={resetZoom}
            style={{ background: 'rgba(255,255,255,0.1)', border: 'none', color: '#fff', cursor: 'pointer', borderRadius: 7, padding: '0.3rem 0.7rem', fontSize: '0.8rem' }}
          >
            1:1
          </button>
          <button
            onClick={onClose}
            style={{ background: 'rgba(255,255,255,0.1)', border: 'none', color: '#fff', cursor: 'pointer', borderRadius: 7, padding: '0.3rem 0.7rem', fontSize: '1rem', lineHeight: 1 }}
          >
            ✕
          </button>
        </div>
      </div>

      {/* Image */}
      <div
        onClick={(e) => e.stopPropagation()}
        onWheel={onWheel}
        style={{ cursor: scale > 1 ? 'zoom-out' : 'zoom-in', marginTop: 52 }}
      >
        <img
          ref={imgRef}
          src={src}
          alt={label}
          onClick={() => setScale((s) => s === 1 ? 2 : 1)}
          style={{
            maxWidth: 'min(90vw, 800px)',
            maxHeight: 'calc(90vh - 52px)',
            objectFit: 'contain',
            transform: `scale(${scale})`,
            transformOrigin: 'center center',
            transition: 'transform 0.2s ease',
            borderRadius: scale === 1 ? 12 : 0,
            display: 'block',
          }}
        />
      </div>

      {/* Zoom hint */}
      {scale === 1 && (
        <div style={{ position: 'absolute', bottom: 20, fontSize: '0.75rem', color: 'rgba(255,255,255,0.4)' }}>
          Clic o rueda del mouse para ampliar · Esc para cerrar
        </div>
      )}
    </div>
  );
}
