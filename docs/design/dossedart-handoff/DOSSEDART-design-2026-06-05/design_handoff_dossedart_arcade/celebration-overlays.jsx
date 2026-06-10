// DOSSEDART — Celebration overlays (in-game "juice")
// Transient overlays shown OVER the cockpit during play. The app already has
// sound/video hooks for these event folders: winner · bullseye · bust ·
// checkout · high_round · low_round · three_misses (+ Shanghai instant-win).
// Two scales:
//   BIG TAKEOVER (dismiss → post-game):  VINNER · SHANGHAI!
//   QUICK FLASH (auto-dismiss mid-turn):  180 · CHECKOUT · BULLSEYE · BUST · 3 BOM
// All over a dimmed ghost-board backdrop. Same arcade tokens.

const OV_W = 820, OV_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const GREEN   = '#3DFF8E';
const RED      = '#FF3050';
const ORANGE  = '#FF7A00';
const BG      = '#0a0014';
const PHOSPHOR= '#D9D2C2';

if (typeof document !== 'undefined' && !document.getElementById('ov-kf')) {
  const s = document.createElement('style');
  s.id = 'ov-kf';
  s.textContent = `
    @keyframes ovPop { 0%{transform:scale(.6); opacity:0} 60%{transform:scale(1.08); opacity:1} 100%{transform:scale(1)} }
    @keyframes ovPulse { 0%,100%{opacity:1} 50%{opacity:.55} }
    @keyframes ovSpin { from{transform:translate(-50%,-50%) rotate(0)} to{transform:translate(-50%,-50%) rotate(360deg)} }
    @keyframes ovShake { 0%,100%{transform:translateX(0)} 20%{transform:translateX(-8px)} 40%{transform:translateX(8px)} 60%{transform:translateX(-5px)} 80%{transform:translateX(5px)} }
    @keyframes ovStar { 0%,100%{opacity:.4; transform:translateY(0)} 50%{opacity:1; transform:translateY(-4px)} }
    @media (prefers-reduced-motion: reduce){ .ov-pop,.ov-pulse,.ov-spin,.ov-shake,.ov-star{animation:none!important} }`;
  document.head.appendChild(s);
}

// ── shared pieces ───────────────────────────────────────────────
const Crown = ({ size=56 }) => (
  <svg width={size} height={size*0.72} viewBox="0 0 28 20" style={{display:'block', filter:`drop-shadow(0 0 8px ${YELLOW}aa)`}}>
    <path d="M2 18 L4.5 5 L9.5 12 L14 2.5 L18.5 12 L23.5 5 L26 18 Z" fill={YELLOW} stroke="#a87b00" strokeWidth="1"/>
    <rect x="2" y="16.5" width="24" height="3.5" fill={YELLOW} stroke="#a87b00" strokeWidth="0.5"/>
  </svg>
);
const Avatar = ({ size=110, color=YELLOW }) => (
  <div style={{width:size, height:size, borderRadius:'50%', background:'#1a0030', border:`3px solid ${color}`, display:'flex', alignItems:'flex-end', justifyContent:'center', flexShrink:0, overflow:'hidden', boxShadow:`0 0 26px ${color}66`}}>
    <svg width={size*0.8} height={size*0.8} viewBox="0 0 24 24" style={{marginBottom:-2}}>
      <circle cx="12" cy="9" r="4.4" fill={color} opacity="0.9"/>
      <path d="M3.5 22c0-5 3.8-8 8.5-8s8.5 3 8.5 8z" fill={color} opacity="0.9"/>
    </svg>
  </div>
);
const Bull = ({ size=150 }) => (
  <svg width={size} height={size} viewBox="0 0 100 100" style={{display:'block', filter:`drop-shadow(0 0 14px ${RED}88)`}}>
    <circle cx="50" cy="50" r="46" fill="#1e0c40" stroke={`${MAGENTA}66`} strokeWidth="2"/>
    <circle cx="50" cy="50" r="30" fill="none" stroke="#321760" strokeWidth="6"/>
    <circle cx="50" cy="50" r="20" fill={GREEN} opacity="0.25"/>
    <circle cx="50" cy="50" r="13" fill={RED} stroke={YELLOW} strokeWidth="2"/>
    <circle cx="50" cy="50" r="5" fill={YELLOW} stroke="#a87b00" strokeWidth="1"/>
  </svg>
);
const Rays = ({ color, n=26 }) => (
  <svg width={900} height={900} viewBox="0 0 900 900" className="ov-spin" style={{position:'absolute', left:'50%', top:'50%', transform:'translate(-50%,-50%)', opacity:0.16, pointerEvents:'none', zIndex:1, animation:'ovSpin 26s linear infinite'}}>
    {Array.from({length:n}).map((_,i)=>{ const a=(i/n)*2*Math.PI; const x2=450+Math.cos(a)*640, y2=450+Math.sin(a)*640; return <line key={i} x1={450} y1={450} x2={x2} y2={y2} stroke={color} strokeWidth={i%2?20:8}/>; })}
  </svg>
);
const GhostBoard = () => (
  <svg width={620} height={620} viewBox="0 0 620 620" style={{position:'absolute', left:'50%', top:'50%', transform:'translate(-50%,-50%)', opacity:0.10, pointerEvents:'none', zIndex:0}}>
    <circle cx="310" cy="310" r="300" fill="none" stroke={PHOSPHOR} strokeWidth="2"/>
    <circle cx="310" cy="310" r="200" fill="none" stroke={PHOSPHOR} strokeWidth="1"/>
    <circle cx="310" cy="310" r="60" fill="none" stroke={PHOSPHOR} strokeWidth="1"/>
    {Array.from({length:20}).map((_,i)=>{ const a=(i/20)*2*Math.PI, x=310+Math.cos(a)*300, y=310+Math.sin(a)*300; return <line key={i} x1="310" y1="310" x2={x} y2={y} stroke={PHOSPHOR} strokeWidth="0.5"/>; })}
  </svg>
);
const Confetti = () => {
  const bits = [[8,16,YELLOW],[22,40,CYAN],[14,72,MAGENTA],[30,12,GREEN],[83,20,YELLOW],[90,52,CYAN],[76,80,MAGENTA],[68,30,YELLOW],[44,8,CYAN],[58,86,GREEN],[6,55,MAGENTA],[94,75,YELLOW]];
  return <>{bits.map(([x,y,c],i)=>(
    <div key={i} className="ov-star" style={{position:'absolute', left:`${x}%`, top:`${y}%`, width:i%3?7:10, height:i%3?7:10, background:c, boxShadow:`0 0 8px ${c}`, transform:`rotate(${i*37}deg)`, opacity:0.7, zIndex:1, animation:`ovStar ${1.2+(i%4)*0.3}s ease-in-out infinite`}}></div>
  ))}</>;
};

const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const Overlay = ({ accent, dim=0.8, confetti, children }) => (
  <div style={{width:OV_W, height:OV_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', position:'relative', overflow:'hidden', display:'flex', alignItems:'center', justifyContent:'center'}}>
    <GhostBoard/>
    <div style={{position:'absolute', inset:0, background:`rgba(10,0,20,${dim})`}}></div>
    <div style={{position:'absolute', inset:0, background:`radial-gradient(ellipse at center, ${accent}26 0%, transparent 62%)`, pointerEvents:'none'}}></div>
    <Rays color={accent}/>
    {confetti && <Confetti/>}
    <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
    <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
    <div className="ov-pop" style={{position:'relative', zIndex:6, display:'flex', flexDirection:'column', alignItems:'center', textAlign:'center', padding:'0 40px', animation:'ovPop .5s cubic-bezier(.2,.9,.3,1.2) both'}}>{children}</div>
  </div>
);
const Hint = ({ children }) => (
  <div style={{marginTop:34, fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.45)', letterSpacing:3}}>{children}</div>
);
const Chip = ({ color, children }) => (
  <div style={{padding:'8px 14px', border:`2px solid ${color}`, background:`${color}12`, fontFamily:'"Press Start 2P", monospace', fontSize:13, color, textShadow:`0 0 8px ${color}aa`, letterSpacing:1}}>{children}</div>
);

// ── BIG TAKEOVERS ───────────────────────────────────────────────
const Winner = () => (
  <Overlay accent={YELLOW} dim={0.82} confetti>
    <Crown size={64}/>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:16, color:YELLOW, letterSpacing:5, textShadow:`0 0 10px ${YELLOW}aa`, margin:'14px 0 18px'}}>VINNER</div>
    <Avatar size={120} color={YELLOW}/>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:40, color:'#fff', letterSpacing:1, textShadow:`0 0 20px ${YELLOW}88`, margin:'18px 0 16px'}}>JONAS</div>
    <div style={{display:'flex', gap:12}}>
      <Chip color={YELLOW}>X01 · 501</Chip>
      <Chip color={GREEN}>ELO +12.3</Chip>
    </div>
    <Hint>TRYKK FOR RESULTAT ▸</Hint>
  </Overlay>
);
const Shanghai = () => (
  <Overlay accent={YELLOW} dim={0.78} confetti>
    <div className="ov-pulse" style={{fontFamily:'"Press Start 2P", monospace', fontSize:62, color:YELLOW, letterSpacing:2, lineHeight:1.05, textShadow:`0 0 28px ${YELLOW}, 0 0 50px ${ORANGE}88`, animation:'ovPulse 0.8s ease-in-out infinite'}}>SHANGHAI!</div>
    <div style={{display:'flex', gap:14, margin:'28px 0 18px'}}>
      {['S','D','T'].map(l=>(
        <div key={l} style={{width:72, height:72, border:`3px solid ${GREEN}`, background:`${GREEN}1a`, boxShadow:`0 0 18px ${GREEN}66`, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:3}}>
          <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:22, color:GREEN, textShadow:`0 0 10px ${GREEN}`}}>{l}3</span>
          <span style={{fontFamily:'"VT323", monospace', fontSize:13, color:GREEN}}>✓</span>
        </div>
      ))}
    </div>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:14, color:'#fff', letterSpacing:2}}>JONAS · DIREKTE SEIER</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.6)', letterSpacing:2, marginTop:10}}>single + dobbel + trippel av 3 — i én tur</div>
    <Hint>TRYKK FOR RESULTAT ▸</Hint>
  </Overlay>
);

// ── QUICK FLASHES ───────────────────────────────────────────────
const Flash180 = () => (
  <Overlay accent={YELLOW} dim={0.74}>
    <div className="ov-pulse" style={{fontFamily:'"Archivo", sans-serif', fontWeight:900, fontSize:200, color:YELLOW, lineHeight:0.9, letterSpacing:-4, textShadow:`0 0 36px ${YELLOW}, 0 0 70px ${ORANGE}88`, animation:'ovPulse 0.7s ease-in-out infinite'}}>180</div>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:20, color:'#fff', letterSpacing:4, marginTop:6}}>MAKS RUNDE</div>
    <div style={{display:'flex', gap:10, marginTop:22}}>
      {['T20','T20','T20'].map((d,i)=><Chip key={i} color={GREEN}>{d}</Chip>)}
    </div>
  </Overlay>
);
const Checkout = () => (
  <Overlay accent={GREEN} dim={0.76}>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:46, color:GREEN, letterSpacing:2, textShadow:`0 0 24px ${GREEN}aa`}}>CHECKOUT!</div>
    <div style={{fontFamily:'"Archivo", sans-serif', fontWeight:900, fontSize:128, color:'#fff', lineHeight:1, textShadow:`0 0 28px ${GREEN}66`, margin:'10px 0 6px'}}>121</div>
    <div style={{display:'flex', gap:10, marginTop:14}}>
      <Chip color={GREEN}>T20</Chip><Chip color={GREEN}>T20</Chip><Chip color={GREEN}>D-BULL</Chip>
    </div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.6)', letterSpacing:2, marginTop:18}}>JONAS tar legget</div>
  </Overlay>
);
const Bullseye = () => (
  <Overlay accent={RED} dim={0.76}>
    <Bull size={170}/>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:46, color:YELLOW, letterSpacing:3, textShadow:`0 0 22px ${YELLOW}aa`, margin:'22px 0 8px'}}>BULLSEYE</div>
    <div style={{fontFamily:'"Archivo", sans-serif', fontWeight:900, fontSize:74, color:'#fff', lineHeight:1, textShadow:`0 0 20px ${RED}66`}}>50</div>
  </Overlay>
);
const Bust = () => (
  <Overlay accent={RED} dim={0.8}>
    <div className="ov-shake" style={{fontFamily:'"Press Start 2P", monospace', fontSize:84, color:RED, letterSpacing:2, textShadow:`0 0 30px ${RED}, 0 0 60px ${RED}66`, animation:'ovShake .5s ease-in-out'}}>BUST!</div>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:16, color:'#fff', letterSpacing:2, marginTop:24}}>DU OVERSKJØT</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:19, color:'rgba(255,255,255,0.6)', letterSpacing:2, marginTop:10}}>scoren står — turen er over</div>
  </Overlay>
);
const ThreeMiss = () => (
  <Overlay accent={ORANGE} dim={0.8}>
    <div style={{display:'flex', gap:16, marginBottom:24}}>
      {[0,1,2].map(i=><span key={i} style={{fontFamily:'"Press Start 2P", monospace', fontSize:44, color:ORANGE, textShadow:`0 0 12px ${ORANGE}aa`}}>✗</span>)}
    </div>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:52, color:ORANGE, letterSpacing:2, textShadow:`0 0 22px ${ORANGE}aa`}}>3 BOM</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:19, color:'rgba(255,255,255,0.6)', letterSpacing:2, marginTop:16}}>ingen score denne runden …</div>
  </Overlay>
);

// ── spec ────────────────────────────────────────────────────────
const SpecRow = ({ zone, val, hex }) => (
  <div style={{display:'flex', alignItems:'center', gap:10, padding:'7px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
    <div style={{width:14, height:14, background:hex, border:'1px solid rgba(0,0,0,0.25)', flexShrink:0}}></div>
    <div style={{flex:1, fontFamily:'"Inter", system-ui, sans-serif', fontSize:13, fontWeight:600, color:'#2a251f'}}>{zone}</div>
    <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:12, color:'#5a544a'}}>{val}</div>
  </div>
);
const SpecCard = () => (
  <div style={{boxSizing:'border-box', width:680, height:1180, background:'#fffdf6', border:'1.5px solid rgba(0,0,0,0.14)', padding:'30px 34px', fontFamily:'"Inter", system-ui, sans-serif', display:'flex', flexDirection:'column', gap:14, overflow:'hidden'}}>
    <div>
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Implementasjon · feiring</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:27, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Celebration overlays</div>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Slutt-feiring</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}><b style={{color:'#2a251f'}}>VINNER</b> og <b style={{color:'#2a251f'}}>SHANGHAI!</b> dekker skjermen og avsluttes til post-game ved trykk — over en dimmet ghost-board med roterende stråler + konfetti. Midt-i-turen-momenter (180, checkout, bullseye, bust, 3 bom) dekkes allerede av appens <b style={{color:'#2a251f'}}>video- og lydklipp</b>, så egne overlays er ikke nødvendig.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Trigger → eksisterende hooks</div>
      <SpecRow zone="VINNER" val="VideoService 'winner' · winnerIndex" hex={YELLOW}/>
      <SpecRow zone="SHANGHAI!" val="isInstantShanghai (S+D+T i tur)" hex={YELLOW}/>
      <SpecRow zone="Midt-i-turen" val="dekkes av video/lyd-klipp" hex={PHOSPHOR}/>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Bygg + best practice</div>
      {[
        ['1','Overlay-lag','Render over cockpiten i en Stack/Overlay. Dimmet veil + ghost-board + roterende stråler + scanlines. Respekter prefers-reduced-motion (pop/puls/spin av → vis sluttilstand).'],
        ['2','Takeover-flyt','Overlay venter på trykk (→ post-game) eller en kort auto-timer. Maks én om gangen; blokker ikke input lenger enn nødvendig.'],
        ['3','Gjenbruk hooks','Knytt til eksisterende VideoService/SoundService-events (assets/videos/*, assets/sounds/*). Overlay kan vises i stedet for / sammen med klipp når video er av.'],
        ['4','Farge per hendelse','Gull=seier/180/shanghai, grønn=checkout, rød=bullseye/bust, oransje=3 bom. Samme token-rolle som ellers.'],
        ['5','Ikke i veien','Aldri blokker input lenger enn nødvendig. Flash er ikke-interaktiv og forsvinner; takeover har tydelig «trykk for resultat».'],
      ].map(([n,t,b])=>(
        <div key={n} style={{display:'flex', gap:11, padding:'8px 0', borderBottom:'1px solid rgba(0,0,0,0.07)'}}>
          <div style={{flexShrink:0, width:22, height:22, borderRadius:'50%', background:'#2a8a52', color:'#fff', display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"JetBrains Mono", monospace', fontSize:12, fontWeight:700}}>{n}</div>
          <div style={{flex:1}}>
            <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:700, color:'#2a251f', marginBottom:2}}>{t}</div>
            <div style={{fontFamily:'"Inter", sans-serif', fontSize:12, lineHeight:1.5, color:'#5a544a'}}>{b}</div>
          </div>
        </div>
      ))}
    </div>
    <div style={{marginTop:'auto', padding:'12px 14px', background:'#dcefe1', border:'1px solid rgba(42,138,82,0.3)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, lineHeight:1.55, color:'#2a4a36'}}>
        <b>Konsistens:</b> samme tokens + CRT-chrome som cockpit-ene. Disse momentene binder alle seks modusene sammen og gjør appen levende — uten å forstyrre spillet.
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const CelebrationOverlays = () => (
  <>
    <DCSection id="ov-takeover" title="Celebration — takeover (slutt-feiring)" subtitle="Dekker skjermen, avsluttes til post-game ved trykk. Over en dimmet ghost-board med roterende stråler + konfetti.">
      <DCArtboard id="ov-winner" label="VINNER · kamp vunnet" width={OV_W} height={OV_H}><Winner/></DCArtboard>
      <DCArtboard id="ov-shanghai" label="SHANGHAI! · direkte seier" width={OV_W} height={OV_H}><Shanghai/></DCArtboard>
    </DCSection>
    <DCSection id="ov-impl" title="Celebration — implementasjon" subtitle="Trigger-mapping til eksisterende VideoService/SoundService-hooks + bygge-noter.">
      <DCArtboard id="ov-spec" label="Implementasjon · spec + triggers" width={680} height={1180}><SpecCard/></DCArtboard>
    </DCSection>
  </>
);
window.CelebrationOverlays = CelebrationOverlays;
