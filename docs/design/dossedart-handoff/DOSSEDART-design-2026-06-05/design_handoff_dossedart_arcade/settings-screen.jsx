// DOSSEDART — Settings screen
// Reached from post-game ⚙ INNST. + home. A long preferences form, so this is
// ONE crafted arcade screen (not competing directions), shown two ways: as it
// sits on the device (820×1180, scrolls) and the full scroll content.
// Sections (from settings_screen.dart): Handicap · ELO · Text-to-speech ·
// Sound & video · Memes · Log mode · Experimental · Feedback.
// Arcade controls match the setup-screen vocabulary (cyan active, magenta frame).

const SE_W = 820;

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const GREEN   = '#3DFF8E';
const RED      = '#FF3050';
const ORANGE  = '#FF7A00';
const BG      = '#0a0014';
const SURFACE = '#160a2b';
const PHOSPHOR= '#D9D2C2';

// ── arcade controls ─────────────────────────────────────────────
const Toggle = ({ on }) => (
  <div style={{width:50, height:27, borderRadius:14, border:`2px solid ${on?CYAN:'rgba(255,255,255,0.25)'}`, background:on?`${CYAN}22`:'transparent', boxShadow:on?`0 0 10px ${CYAN}55`:'none', position:'relative', flexShrink:0}}>
    <div style={{position:'absolute', top:2, left:on?25:2, width:19, height:19, borderRadius:'50%', background:on?CYAN:'rgba(255,255,255,0.4)', boxShadow:on?`0 0 8px ${CYAN}`:'none', transition:'left .15s'}}></div>
  </div>
);
const Row = ({ label, sub, children, last }) => (
  <div style={{display:'flex', alignItems:'center', gap:14, padding:'13px 0', borderBottom:last?'none':'1px solid rgba(255,255,255,0.07)'}}>
    <div style={{flex:1, minWidth:0}}>
      <div style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:15, color:'#fff'}}>{label}</div>
      {sub && <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.5)', letterSpacing:.5, marginTop:3, lineHeight:1.3}}>{sub}</div>}
    </div>
    {children}
  </div>
);
const Slider = ({ label, value, lo, hi, pct, sub }) => (
  <div style={{padding:'13px 0', borderBottom:'1px solid rgba(255,255,255,0.07)'}}>
    <div style={{display:'flex', alignItems:'center', justifyContent:'space-between'}}>
      <span style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:15, color:'#fff'}}>{label}</span>
      <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:YELLOW, textShadow:`0 0 6px ${YELLOW}66`, padding:'4px 8px', border:`1px solid ${YELLOW}55`, background:`${YELLOW}10`}}>{value}</span>
    </div>
    {sub && <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:.5, marginTop:5, lineHeight:1.3}}>{sub}</div>}
    <div style={{position:'relative', height:8, background:`${MAGENTA}22`, marginTop:12}}>
      <div style={{position:'absolute', inset:0, width:`${pct}%`, background:CYAN, boxShadow:`0 0 8px ${CYAN}aa`}}></div>
      <div style={{position:'absolute', top:-5, left:`calc(${pct}% - 8px)`, width:16, height:18, background:CYAN, border:'2px solid #fff', boxShadow:`0 0 8px ${CYAN}`}}></div>
    </div>
    <div style={{display:'flex', justifyContent:'space-between', marginTop:6, fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.35)', letterSpacing:1}}>
      <span>{lo}</span><span>{hi}</span>
    </div>
  </div>
);
const Segmented = ({ label, options, active, last }) => (
  <div style={{padding:'13px 0', borderBottom:last?'none':'1px solid rgba(255,255,255,0.07)'}}>
    <div style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:15, color:'#fff', marginBottom:10}}>{label}</div>
    <div style={{display:'flex', gap:8}}>
      {options.map(o=>{ const on=o===active; return (
        <div key={o} style={{flex:1, padding:'11px 0', textAlign:'center', border:`2px solid ${on?CYAN:'rgba(255,255,255,0.18)'}`, background:on?`${CYAN}16`:'transparent', boxShadow:on?`0 0 10px ${CYAN}44`:'none', fontFamily:'"Press Start 2P", monospace', fontSize:10, letterSpacing:1, color:on?CYAN:'rgba(255,255,255,0.55)'}}>{o}</div>
      );})}
    </div>
  </div>
);
const Select = ({ label, value, last }) => (
  <Row label={label} last={last}>
    <div style={{display:'flex', alignItems:'center', gap:9, padding:'8px 12px', border:`2px solid ${CYAN}66`, background:`${CYAN}0c`}}>
      <span style={{fontFamily:'"VT323", monospace', fontSize:17, color:CYAN, letterSpacing:1}}>{value}</span>
      <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:9, color:CYAN}}>▾</span>
    </div>
  </Row>
);
const Section = ({ title, children, note }) => (
  <div>
    <div style={{display:'flex', alignItems:'center', gap:10, marginBottom:9}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:MAGENTA, letterSpacing:2, textShadow:`0 0 6px ${MAGENTA}66`}}>{title}</div>
      <div style={{flex:1, height:1, background:`${MAGENTA}33`}}></div>
      {note && <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.4)', letterSpacing:1}}>{note}</div>}
    </div>
    <div style={{border:`2px solid ${MAGENTA}44`, background:SURFACE, padding:'2px 16px'}}>{children}</div>
  </div>
);

// ── chrome ──────────────────────────────────────────────────────
const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
const Header = () => (
  <div style={{padding:'12px 18px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:12, position:'relative', zIndex:6, flexShrink:0}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:CYAN, letterSpacing:2}}>◀ TILBAKE</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:12, color:YELLOW, letterSpacing:2, textShadow:`0 0 6px ${YELLOW}88`}}>INNSTILLINGER</div>
    <div style={{width:84}}></div>
  </div>
);

// the full settings body (all sections)
const SettingsBody = () => (
  <div style={{padding:'18px 16px 22px', display:'flex', flexDirection:'column', gap:20}}>
    <Section title="HANDICAP">
      <Slider label="Skala-faktor" value="0.50" lo="0.10" hi="2.00" pct={21} sub="Poeng per rating-poeng over/under 1200. En 1400-spiller starter +100 poeng." />
      <div style={{height:1}}></div>
    </Section>

    <Section title="ELO-RATING">
      <Slider label="K-faktor · nye spillere" value="24" lo="8" hi="64" pct={29} sub="Rating-endring per kamp for spillere med < 15 kamper." />
      <Slider label="K-faktor · erfarne" value="16" lo="4" hi="48" pct={27} sub="Rating-endring per kamp for spillere med ≥ 15 kamper." />
      <Slider label="Erfarings-terskel" value="15 kamper" lo="5" hi="50" pct={22} sub="Etter dette synker K-faktor fra 24 til 16." />
      <div style={{height:1}}></div>
    </Section>

    <Section title="TEKST-TIL-TALE">
      <Row label="Aktiver TTS" sub="Stemme-annonseringer under spill"><Toggle on/></Row>
      <Select label="Språk" value="Norsk (bokmål)" />
      <Select label="Stemme" value="Standard" />
      <div style={{padding:'12px 0 6px', fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.45)', letterSpacing:2}}>ANNONSER</div>
      <Row label="Neste spiller"><Toggle on/></Row>
      <Row label="Kast-resultat"><Toggle on/></Row>
      <Row label="Score / gjenstående"><Toggle on/></Row>
      <Row label="Vinner"><Toggle on/></Row>
      <Row label="Spill-hendelser" sub="Bust, halvert, eliminert, killer …" last><Toggle on/></Row>
    </Section>

    <Section title="LYD & VIDEO">
      <Row label="Lydeffekter" sub="Spiller .mp3 fra assets/sounds/ ved hendelser"><Toggle on/></Row>
      <Row label="Video-hendelser" sub="Viser .mp4-klipp ved spesielle kast" last><Toggle on/></Row>
    </Section>

    <Section title="MEMES" note="hold inne for mer">
      <Row label="Aktiver memes" sub="Morsomme annonseringer under spill" last><Toggle/></Row>
    </Section>

    <Section title="LOGG">
      <Segmented label="Logg-modus" options={['FULL','MINIMAL','AV']} active="FULL" last/>
    </Section>

    <Section title="EKSPERIMENTELT">
      <Row label="DOSSEDART-design" sub="Arcade-redesign. Start appen på nytt for å aktivere." last><Toggle on/></Row>
    </Section>

    <Section title="TILBAKEMELDING">
      <div style={{display:'flex', alignItems:'center', gap:13, padding:'14px 0'}}>
        <div style={{width:40, height:40, border:`2px solid ${CYAN}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"VT323", monospace', fontSize:22, color:CYAN, flexShrink:0}}>✉</div>
        <div style={{flex:1}}>
          <div style={{fontFamily:'"Inter", system-ui, sans-serif', fontWeight:700, fontSize:15, color:'#fff'}}>Send tilbakemelding</div>
          <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'rgba(255,255,255,0.5)', letterSpacing:.5, marginTop:2}}>Meld en feil eller foreslå en forbedring</div>
        </div>
        <span style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN}}>›</span>
      </div>
    </Section>
  </div>
);

// device view (820×1180, scrolls — clipped here with a scroll track)
const SettingsDevice = () => (
  <div style={{width:SE_W, height:1180, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
    <Header/>
    <div style={{flex:1, overflow:'hidden', position:'relative'}}>
      <SettingsBody/>
      {/* scroll track hint */}
      <div style={{position:'absolute', top:10, right:5, bottom:10, width:4, background:'rgba(255,255,255,0.06)', zIndex:7}}>
        <div style={{width:'100%', height:'42%', background:`${CYAN}66`, boxShadow:`0 0 6px ${CYAN}66`}}></div>
      </div>
      {/* fade to imply more below */}
      <div style={{position:'absolute', left:0, right:0, bottom:0, height:60, background:`linear-gradient(transparent, ${BG})`, pointerEvents:'none', zIndex:6}}></div>
    </div>
  </div>
);

// full content view (everything, no clip)
const SettingsFull = ({ height }) => (
  <div style={{width:SE_W, minHeight:height, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', position:'relative'}}>
    <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
    <Header/>
    <SettingsBody/>
  </div>
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
      <div style={{fontFamily:'"JetBrains Mono", monospace', fontSize:11, letterSpacing:2, color:'#c96442', textTransform:'uppercase', fontWeight:600, marginBottom:6}}>Implementasjon · innstillinger</div>
      <div style={{fontFamily:'"Archivo", "Inter", sans-serif', fontSize:27, fontWeight:900, letterSpacing:-0.5, color:'#2a251f', lineHeight:1.05}}>Innstillinger · arcade-form</div>
    </div>
    <div style={{padding:'12px 14px', background:'#f4f0e8', border:'1px solid rgba(0,0,0,0.08)'}}>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:4}}>Struktur</div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:12.5, color:'#5a544a', lineHeight:1.5}}>Sticky header + scrollende liste av seksjoner. Samme rekkefølge som i dag: Handicap · ELO · Tekst-til-tale · Lyd & video · Memes · Logg · Eksperimentelt · Tilbakemelding. Arcade-kontroller erstatter Material Slider/Switch/Radio — men samme <code style={{fontFamily:'"JetBrains Mono",monospace', fontSize:11, background:'#ece7dd', padding:'1px 4px'}}>AppSettings</code>-kall.</div>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:6, textTransform:'uppercase', letterSpacing:0.5}}>Kontroller → kilde</div>
      <SpecRow zone="Bryter (Toggle)" val="AppSettings.set* · TtsService" hex={CYAN}/>
      <SpecRow zone="Slider (handicap / ELO K / terskel)" val="setHandicapScale · setEloK* " hex={CYAN}/>
      <SpecRow zone="Segmentert (logg-modus)" val="setLogMode (full/minimal/off)" hex={MAGENTA}/>
      <SpecRow zone="Select (språk / stemme)" val="TtsService.setLanguage/Voice" hex={CYAN}/>
      <SpecRow zone="Seksjon-label / ramme" val="#FF00AA" hex={MAGENTA}/>
      <SpecRow zone="Verdi-chip / fremhevet" val="#FFD200" hex={YELLOW}/>
    </div>
    <div>
      <div style={{fontFamily:'"Inter", sans-serif', fontSize:13, fontWeight:800, color:'#2a251f', marginBottom:8, textTransform:'uppercase', letterSpacing:0.5}}>Bygg + best practice</div>
      {[
        ['1','Arcade-kontroller','Bryter = cyan pill m/ knapp + glød. Slider = magenta spor + cyan fyll + firkant-knapp + gul verdi-chip. Segmentert = cyan aktiv. Select = cyan ramme + ▾. Match setup-skjermenes primitives.'],
        ['2','Betingede felt','Når TTS er av → skjul språk/stemme + annonser-bryterne (som i dag). Memes long-press → meme-innstillinger beholdes.'],
        ['3','Lever fra AppSettings','Ingen ny lagring — bind hver kontroll til eksisterende AppSettings/TtsService/EloService-kall. Verdiene her er bare standard-eksempler.'],
        ['4','Eksperimentelt = meta','«DOSSEDART-design»-bryteren er nettopp dette redesignet. Når alt er live kan flagget fjernes og arcade bli standard.'],
        ['5','Entry/retur','Nås fra post-game ⚙ INNST. + hjem. ◀ TILBAKE returnerer. Tilbakemelding åpner del-ark (SharePlus).'],
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
        <b>Konsistens:</b> samme chrome + farge-prinsipp som cockpit-ene, post-game og statistikk. Cyan = aktiv/på, magenta = seksjon/ramme, gul = verdi. Innstillinger fullfører sett-et: 6 spillmodus + post-game + statistikk + innstillinger.
      </div>
    </div>
  </div>
);

// ── Canvas ──────────────────────────────────────────────────────
const SettingsScreenDesign = () => (
  <DCSection
    id="settings"
    title="Innstillinger — skjerm"
    subtitle="Nås fra post-game ⚙ INNST. + hjem. Én lang preferanse-form, arcade-stilt: Handicap · ELO · Tekst-til-tale · Lyd & video · Memes · Logg · Eksperimentelt · Tilbakemelding. Vist både slik den sitter på enheten (scroller) og som full innholds-høyde. Arcade-kontroller (bryter/slider/segmentert/select) i samme språk som setup-skjermene.">
    <DCArtboard id="se-device" label="På enhet (820×1180 · scroller)" width={SE_W} height={1180}><SettingsDevice/></DCArtboard>
    <DCArtboard id="se-full" label="Full skjerm · alle seksjoner" width={SE_W} height={1860}><SettingsFull height={1860}/></DCArtboard>
    <DCArtboard id="se-spec" label="Implementasjon · spec + kontroller" width={680} height={1180}><SpecCard/></DCArtboard>
  </DCSection>
);
window.SettingsScreenDesign = SettingsScreenDesign;
