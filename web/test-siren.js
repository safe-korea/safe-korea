/* Own-device test audio only. Never a background Web Push sound. */
(() => {
  'use strict';
  let context,buffer,loading,source,armedAt=0,generation=0;
  function stop(){generation++;if(source){source.onended=null;source.stop();source=null;}}
  async function prepare(){
    const AudioContext=window.AudioContext||window.webkitAudioContext;
    if(!AudioContext)return false;
    try{
      context ||= new AudioContext();
      // Called directly by a click; never attempt to unlock audio from a push.
      const resumed=context.resume();
      loading ||= fetch(new URL('audio/drill_siren.wav',document.baseURI),{credentials:'omit'})
        .then(r=>{if(!r.ok)throw Error('audio_unavailable');return r.arrayBuffer();})
        .then(bytes=>context.decodeAudioData(bytes))
        .then(value=>buffer=value).catch(error=>{loading=null;throw error;});
      await Promise.all([resumed,loading]);return context.state==='running';
    }catch{return false;}
  }
  function start(){
    if(document.hidden||!buffer||context?.state!=='running')return false;
    try{
      stop();source=context.createBufferSource();source.buffer=buffer;
      source.connect(context.destination);source.onended=()=>{source=null;};source.start();return true;
    }catch{stop();return false;}
  }
  window.safeKorPlayTestSiren=async()=>{const ticket=++generation;return await prepare()&&ticket===generation?start():false;};
  window.safeKorStopTestSiren=stop;
  window.safeKorTestSiren={
    prepare,
    isPlaying:()=>!!source,
    arm(enabled){armedAt=enabled?Date.now():0;},
    onNotice(value){
      if(value.type!=='test'||!armedAt||Date.now()-armedAt>60000)return false;
      armedAt=0;return start();
    },
  };
  document.addEventListener('visibilitychange',()=>{if(document.hidden)stop();});
  window.addEventListener('pagehide',stop);
})();
