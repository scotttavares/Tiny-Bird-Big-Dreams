// Stars
const s=document.getElementById('stars');
if(s){
  for(let i=0;i<90;i++){
    const el=document.createElement('div');
    el.className='star';
    const sz=Math.random()*2.5+.5;
    el.style.cssText=`width:${sz}px;height:${sz}px;top:${Math.random()*75}%;left:${Math.random()*100}%;--d:${2+Math.random()*4}s;--dl:${Math.random()*4}s;--lo:${.06+Math.random()*.14};--hi:${.45+Math.random()*.5};`;
    s.appendChild(el);
  }
}

// Hamburger
const ham=document.getElementById('ham');
const mob=document.getElementById('mobileMenu');
if(ham){
  ham.addEventListener('click',()=>{
    ham.classList.toggle('open');
    mob.classList.toggle('open');
    document.body.style.overflow=mob.classList.contains('open')?'hidden':'';
  });
}
function closeMob(){
  if(ham){ ham.classList.remove('open'); mob.classList.remove('open'); }
  document.body.style.overflow='';
}

// Contact form
const form=document.getElementById('contactForm');
if(form){
  form.addEventListener('submit',async(e)=>{
    e.preventDefault();
    const btn=form.querySelector('.form-btn');
    const orig=btn.innerHTML;
    btn.disabled=true;
    btn.textContent='Sending…';
    try{
      const res=await fetch(form.action,{method:'POST',body:new FormData(form),headers:{'Accept':'application/json'}});
      if(res.ok){
        form.style.display='none';
        const ok=document.getElementById('formSuccess');
        ok.style.display='block';
        // Confirm right here, immediately — the server-side banner depends on KV
        // catching up, which can lag a few seconds behind this submit.
        if(!document.getElementById('emailNote')){
          ok.insertAdjacentHTML('afterend','<div id="emailNote" style="background:rgba(232,160,34,.1);border:1px solid rgba(232,160,34,.25);border-radius:16px;padding:20px 28px;margin:24px auto 0;max-width:760px;text-align:center;font-size:14px;color:rgba(251,247,242,.75);line-height:1.75;">🐦&ensp;<strong style="color:#E8A022;">Your message has landed in the nest.</strong>&ensp;We caught it mid-flight and we\'ll swoop back soon.</div>');
        }
      }
      else{ throw new Error(); }
    }catch{ document.getElementById('formError').style.display='block'; btn.disabled=false; btn.innerHTML=orig; }
  });
}

// Back to top
const btt=document.getElementById('backToTop');
if(btt){
  window.addEventListener('scroll',()=>btt.classList.toggle('visible',window.scrollY>400),{passive:true});
  btt.addEventListener('click',()=>window.scrollTo({top:0,behavior:'smooth'}));
}

// Scroll reveal
const obs=new IntersectionObserver((entries)=>{
  entries.forEach((e,i)=>{
    if(e.isIntersecting){
      setTimeout(()=>e.target.classList.add('v'),i*70);
      obs.unobserve(e.target);
    }
  });
},{threshold:.1});
document.querySelectorAll('.reveal').forEach(el=>obs.observe(el));

// Behavior tracking beacon
(function(){
  const vid=document.querySelector('meta[name="tbbd-vid"]')?.content;
  if(!vid)return;
  const vidInput=document.getElementById('tbbdVid');
  if(vidInput)vidInput.value=vid;
  const t0=Date.now();
  let maxScroll=0;
  const clicks=[];
  window.addEventListener('scroll',()=>{
    const d=(window.scrollY+window.innerHeight)/Math.max(1,document.body.scrollHeight);
    if(d>maxScroll)maxScroll=d;
  },{passive:true});
  document.addEventListener('click',e=>{
    const a=e.target.closest('[href]');
    if(a){const h=(a.getAttribute('href')||'').slice(0,60);if(h)clicks.push(h);}
  },{passive:true});
  window.addEventListener('pagehide',()=>{
    if(!navigator.sendBeacon)return;
    navigator.sendBeacon('/track',JSON.stringify({
      vid,
      scrollDepth:Math.round(maxScroll*100)/100,
      timeMs:Date.now()-t0,
      clicks:clicks.slice(0,20)
    }));
  });
})();
