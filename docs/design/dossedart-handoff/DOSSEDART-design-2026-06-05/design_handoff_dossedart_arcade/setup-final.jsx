// DOSSEDART — Setup (final) · shared scaffold, locked conventions
// Matches DossedartSetupScaffold: top bar · RULES (per mode) · PICK YOUR
// FIGHTERS picker · START bar + summary. Random order default ON.
// Locked conventions applied: avatar = player photo if available, else neutral
// silhouette (NO initials/handle box), full names. Shown for two modes (X01 +
// Around the Clock) to prove the scaffold is shared; only RULES differ.

const SU_W = 820, SU_H = 1180;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const PURPLE  = '#7B3FFF';
const GREEN   = '#3DFF8E';
const BG      = '#0a0014';
const SURFACE = '#1a0030';
const PHOSPHOR= '#D9D2C2';

const CAST = [
  { name:'Andreas', form:['W','W','L','W','W'], photo:['#F26A1B','#D14B2A'], sel:true,  slot:1 },
  { name:'Jonas',   form:['L','W','L','W','L'], photo:['#1B7AA8','#3A6B8A'], sel:true,  slot:2 },
  { name:'Mia',     form:['W','L','L','W','L'], photo:null,                  sel:true,  slot:3 },
  { name:'Eva',     form:['L','W','W','L','W'], photo:['#7A4FB0','#9C27B0'], sel:false, slot:null },
  { name:'Ola',     form:['L','L','W','L','L'], photo:null,                  sel:false, slot:null },
];
const HANDICAP_BY = { 1:501, 2:401, 3:301 };

// ── shared bits ─────────────────────────────────────────────────
const Avatar = ({ p, size=46, ring }) => {
  const photo = !!p.photo;
  return (
    <div style={{width:size, height:size, borderRadius:'50%', border:`2px solid ${ring}`,
      background: photo ? `linear-gradient(135deg, ${p.photo[0]} 0%, ${p.photo[1]} 100%)` : '#1a0030',
      boxShadow:`0 0 8px ${ring}55`, display:'flex', alignItems:'flex-end', justifyContent:'center', flexShrink:0, position:'relative', overflow:'hidden'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:'repeating-linear-gradient(0deg, transparent 0px, transparent 2px, rgba(0,0,0,0.18) 3px, transparent 4px)', pointerEvents:'none'}}></div>
      <svg width={size*0.82} height={size*0.82} viewBox="0 0 24 24" style={{marginBottom:-1, position:'relative', zIndex:1}}>
        <circle cx="12" cy="9" r="4.3" fill={photo?'rgba(255,255,255,0.94)':ring} opacity="0.95"/>
        <path d="M3.5 22c0-5 3.8-8 8.5-8s8.5 3 8.5 8z" fill={photo?'rgba(255,255,255,0.94)':ring} opacity="0.95"/>
      </svg>
    </div>
  );
};
const FormPips = ({ form, color, size=12 }) => (
  <div style={{display:'flex', gap:3}}>
    {form.map((f,i)=>(
      <div key={i} style={{width:size, height:size, background:f==='W'?color:'transparent', border:`1.5px solid ${f==='W'?color:'rgba(255,255,255,0.22)'}`, color:f==='W'?BG:'rgba(255,255,255,0.32)', display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:6}}>{f}</div>
    ))}
  </div>
);
const Chip = ({ label, on }) => (
  <div style={{flex:1, padding:'12px 6px', textAlign:'center', background:on?YELLOW:SURFACE, border:`2px solid ${on?YELLOW:MAGENTA}`, color:on?BG:'#fff', fontFamily:'"Press Start 2P", monospace', fontSize:11, letterSpacing:.5, boxShadow:on?`0 0 10px ${YELLOW}88`:'none'}}>{label}</div>
);
const Toggle = ({ label, on, accent=CYAN }) => (
  <div style={{display:'flex', alignItems:'center', gap:10, padding:'10px 12px', background:on?`${accent}22`:SURFACE, border:`2px solid ${on?accent:MAGENTA}`, boxShadow:on?`0 0 10px ${accent}55`:'none'}}>
    <div style={{width:36, height:18, background:on?accent:'rgba(255,255,255,0.12)', position:'relative', flexShrink:0}}>
      <div style={{position:'absolute', top:1, left:on?20:1, width:14, height:14, background:on?BG:'#fff'}}></div>
    </div>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:'#fff', letterSpacing:1}}>{label}</div>
  </div>
);
const Section = ({ label, children }) => (
  <div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.45)', letterSpacing:2, marginBottom:6}}>{label}</div>
    {children}
  </div>
);

const PickerTile = ({ p, handicap }) => {
  const c = p.sel ? YELLOW : MAGENTA;
  const hcap = p.sel && handicap ? HANDICAP_BY[p.slot] : null;
  return (
    <div style={{height:128, boxSizing:'border-box', padding:'14px', background:p.sel?'rgba(255,210,0,0.06)':SURFACE, border:`3px solid ${c}`, boxShadow:p.sel?`0 0 12px ${c}55, inset 0 0 14px ${c}22`:'none', position:'relative', opacity:p.sel?1:0.7, display:'flex', flexDirection:'column'}}>
      {p.sel && <div style={{position:'absolute', top:-9, right:-6, padding:'3px 8px', background:YELLOW, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:10, letterSpacing:1, boxShadow:`0 0 8px ${YELLOW}`, transform:'rotate(4deg)'}}>P{p.slot}</div>}
      <div style={{display:'flex', alignItems:'center', gap:12}}>
        <Avatar p={p} size={46} ring={c}/>
        <div style={{flex:1, minWidth:0, display:'flex', flexDirection:'column', alignItems:'center', gap:6}}>
          <div style={{fontFamily:'"VT323", monospace', fontSize:20, color:'#fff', letterSpacing:1, lineHeight:1}}>{p.name.toUpperCase()}</div>
          <FormPips form={p.form} color={c}/>
        </div>
      </div>
      {hcap && (
        <div style={{marginTop:'auto', padding:'6px 8px', background:`${CYAN}15`, border:`1px dashed ${CYAN}88`, display:'flex', alignItems:'center', justifyContent:'space-between'}}>
          <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:CYAN, letterSpacing:1.5}}>HANDICAP START</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:CYAN, textShadow:`0 0 6px ${CYAN}aa`}}>{hcap}</div>
        </div>
      )}
    </div>
  );
};
const AddTile = () => (
  <div style={{height:128, boxSizing:'border-box', padding:'14px', border:`3px dashed ${CYAN}`, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:8, boxShadow:`inset 0 0 14px ${CYAN}22`}}>
    <div style={{width:46, height:46, border:`2px solid ${CYAN}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:22, color:CYAN, textShadow:`0 0 6px ${CYAN}aa`}}>+</div>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1.5, textShadow:`0 0 6px ${CYAN}aa`}}>ADD PLAYER</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.5)', letterSpacing:1.5}}>NY ELLER GJEST</div>
  </div>
);

const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const SetupShell = ({ title, rules, handicap, summary }) => (
  <div style={{width:SU_W, height:SU_H, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
    <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
    {/* top bar */}
    <div style={{padding:'14px 28px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14}}>
      <div style={{fontFamily:'"VT323", monospace', fontSize:20, color:CYAN, letterSpacing:2}}>◀ HJEM</div>
      <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:14, color:YELLOW, letterSpacing:2, textShadow:`0 0 8px ${YELLOW}88`}}>{title}</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>1CR</div>
    </div>
    {/* rules */}
    <div style={{padding:'18px 28px 16px', borderBottom:`1px dashed ${MAGENTA}66`, display:'flex', flexDirection:'column', gap:12}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1.5}}>► REGLER</div>
      {rules}
    </div>
    {/* picker */}
    <div style={{padding:'16px 28px 0', flex:1, minHeight:0}}>
      <div style={{display:'flex', alignItems:'center', gap:12, marginBottom:12}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1.5}}>► VELG SPILLERE</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:YELLOW, letterSpacing:2}}>3 KLARE</div>
        <div style={{flex:1}}></div>
        <Toggle label="TILFELDIG REKKEFØLGE" on={true} accent={PURPLE}/>
      </div>
      <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:8}}>
        {CAST.map(p => <PickerTile key={p.name} p={p} handicap={handicap}/>)}
        <AddTile/>
      </div>
    </div>
    {/* start */}
    <div style={{padding:'14px 28px 18px', background:'#000', borderTop:`2px solid ${YELLOW}`}}>
      <div style={{padding:'18px 14px', background:`linear-gradient(180deg, ${YELLOW} 0%, #FFA500 100%)`, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:18, letterSpacing:2, textAlign:'center', boxShadow:`0 0 24px ${YELLOW}, inset 0 -4px 0 rgba(0,0,0,0.3)`, border:'3px solid #fff'}}>▶ START KAMP ◀</div>
      <div style={{textAlign:'center', fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.6)', letterSpacing:3, marginTop:10}}>{summary}</div>
    </div>
  </div>
);

// X01 rules: out rule + options (start score chosen on home)
const SetupX01 = () => (
  <SetupShell title="X01 · 501" handicap summary="3 SPILLERE · DOUBLE OUT · HANDICAP · TILFELDIG"
    rules={<>
      <Section label="UT-REGEL">
        <div style={{display:'flex', gap:4}}>
          <Chip label="FRI" on={false}/><Chip label="DOBBEL" on={true}/><Chip label="MASTER" on={false}/>
        </div>
      </Section>
      <Section label="VALG">
        <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:6}}>
          <Toggle label="NO-BUST" on={false} accent={MAGENTA}/>
          <Toggle label="HANDICAP" on={true} accent={CYAN}/>
        </div>
      </Section>
    </>}/>
);
// Around the Clock rules: direction + options — same scaffold, different rules
const SetupATC = () => (
  <SetupShell title="AROUND THE CLOCK" summary="3 SPILLERE · 1→20 · D/T=×N · TILFELDIG"
    rules={<>
      <Section label="RETNING">
        <div style={{display:'flex', gap:4}}>
          <Chip label="1 → 20" on={true}/><Chip label="20 → 1" on={false}/>
        </div>
      </Section>
      <Section label="VALG">
        <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:6}}>
          <Toggle label="BULL" on={false} accent={GREEN}/>
          <Toggle label="D/T = ×N" on={true} accent={CYAN}/>
        </div>
      </Section>
    </>}/>
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
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Implementasjon · oppsett</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:27, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Oppsett · delt scaffold</div>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Hva endres</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Scaffold-en (DossedartSetupScaffold) finnes alt: topbar · REGLER · VELG SPILLERE · START. Eneste finpuss: picker-flisen bruker nå <b style={{color:'#2a251f'}}>foto-eller-silhuett</b> (ingen handle/initial-boks), fulle navn — likt hjem. Alt annet beholdt.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Delt scaffold → per modus</div>
      <SpecRow zone="Topbar · tittel + 1CR" val="widget.title" hex={MAGENTA}/>
      <SpecRow zone="REGLER (per modus)" val="rulesSection(randomOrder)" hex={CYAN}/>
      <SpecRow zone="VELG SPILLERE · picker" val="DossedartPlayerPicker" hex={YELLOW}/>
      <SpecRow zone="Avatar · foto/silhuett" val="sp.avatarPath ?? silhuett" hex={CYAN}/>
      <SpecRow zone="START + summary" val="onStart(players, randomize)" hex={YELLOW}/>
      <SpecRow zone="Rekkefølge tilfeldig (default på)" val="_randomOrder = true" hex={PURPLE}/>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Regler per modus (eksempler)</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12, color:'#5a544a', lineHeight:1.55}}><b style={{color:'#2a251f'}}>X01:</b> ut-regel (fri/dobbel/master) + no-bust/handicap (startscore valgt på hjem). <b style={{color:'#2a251f'}}>ATC:</b> retning + bull + D/T=×N. <b style={{color:'#2a251f'}}>Cricket/Killer/Splitscore/Shanghai:</b> sine egne (lives, runder, target-range osv.) — alle via samme scaffold.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Bygg + best practice</div>
      {[
        ['1','Kun avatar-bytte','Erstatt handle/initial-boksen i DossedartPlayerPicker med foto-eller-silhuett (samme som hjem). Resten av scaffold-en er uendret.'],
        ['2','Fulle navn','Picker-flis viser fullt navn + form-pips (siste 5 W/L). Ingen forkortelser.'],
        ['3','P-slot = rekkefølge','Valgte får P1/P2/P3 i valgt rekkefølge; «tilfeldig» stokker ved start. Handicap-badge kun X01 når på.'],
        ['4','Min-spillere','START deaktivert til min-antall er valgt (Killer ≥2, andre ≥1). Summary speiler valg.'],
        ['5','Legg til / gjest','ADD PLAYER-flis i grid + profil-redigering (foto + navn) ved long-press, som i scaffold-en.'],
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
        <b>Konsistens:</b> samme chrome + tokens som hjem og cockpitene. Avatar-regelen (foto ellers silhuett) er nå lik overalt. Scaffold delt på tvers av alle seks modusene.
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const SetupFinal = () => (
  <DCSection
    id="setup-final"
    title="Oppsett — final (delt scaffold)"
    subtitle="Beholder dagens setup-scaffold (topbar · regler · velg spillere · start). Eneste finpuss: picker-flisen bruker foto-eller-silhuett avatar (ingen initialer), fulle navn — likt hjem. Vist for to modus (X01 + Around the Clock) for å vise at scaffold-en er delt; kun REGLER skiller.">
    <DCArtboard id="setup-x01" label="Oppsett · X01" width={SU_W} height={SU_H}><SetupX01/></DCArtboard>
    <DCArtboard id="setup-atc" label="Oppsett · Around the Clock (samme scaffold)" width={SU_W} height={SU_H}><SetupATC/></DCArtboard>
    <DCArtboard id="setup-spec" label="Implementasjon · spec + scaffold" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.SetupFinal = SetupFinal;
