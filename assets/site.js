// Stars
const s=document.getElementById('stars');
for(let i=0;i<90;i++){
  const el=document.createElement('div');
  el.className='star';
  const sz=Math.random()*2.5+.5;
  el.style.cssText=`width:${sz}px;height:${sz}px;top:${Math.random()*75}%;left:${Math.random()*100}%;--d:${2+Math.random()*4}s;--dl:${Math.random()*4}s;--lo:${.06+Math.random()*.14};--hi:${.45+Math.random()*.5};`;
  s.appendChild(el);
}

// Hamburger
const ham=document.getElementById('ham');
const mob=document.getElementById('mobileMenu');
ham.addEventListener('click',()=>{
  ham.classList.toggle('open');
  mob.classList.toggle('open');
  document.body.style.overflow=mob.classList.contains('open')?'hidden':'';
});
function closeMob(){
  ham.classList.remove('open');
  mob.classList.remove('open');
  document.body.style.overflow='';
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
