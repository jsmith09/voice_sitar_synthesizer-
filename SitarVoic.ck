public class SitarVoic
{
    SndBuf buf => PoleZero micblock => FFT fft_mic => blackhole;
    //adc => PoleZero micblock => FFT fft_mic => blackhole;
    SinOsc vibrato => PulseOsc osc => FFT fft_synth => blackhole;
    Sitar sit => FFT fft_sitar => dac;
    IFFT ifft => PoleZero dcblock => PitShift pit => Chorus chor => LPF lpf => HPF hpf => ADSR env => JCRev rev => Gain g => dac;
    IFFT ifft_sitar => dac;

    me.dir()+"/audio/robgrace.wav" => buf.read;

    1 => buf.gain;
    1 => g.gain;
    1 => osc.gain;


    //fft/ifft constants
    3000 => int FFT_SIZE => fft_mic.size => fft_synth.size => fft_sitar.size => ifft.size => ifft_sitar.size;
    FFT_SIZE/2 => int WIN_SIZE;
    WIN_SIZE/2 => int HOP_SIZE;

    //Filter and Envelop Set up
    hpf.freq(0.001 * 10000);
    lpf.freq(0.999 * 10000);
    env.set(300::ms, 0::ms, 1, 600::ms);
    0.999 => dcblock.blockZero;
    0.999 => micblock.blockZero;

    //Voice Effects 
    0.6 => chor.mix;
    0.2 => chor.modFreq;
    0.3 => chor.modDepth;
    0.05 => rev.mix;
    2 => osc.sync;             
    5 => vibrato.freq;     
    10 => vibrato.gain;
    0.5 => pit.mix;
    0.0 => pit.shift;
    0.0 => float shift;

    //Sitar setup
    float osc_freq;
    
    //Osc setup
    [50, 58, 57, 53, 55] @=> int mel[];
    
    //Mouse Device setup
    false => int requestPitch;
    false => int requestNote;

    // windowing:
    Windowing.hann(WIN_SIZE) => fft_mic.window => fft_synth.window => fft_sitar.window => ifft.window => ifft_sitar.window;

    // spectrum array:
    complex spectrum_synth[WIN_SIZE];
    complex spectrum_mic[WIN_SIZE];
    complex spectrum_sitar[WIN_SIZE];
    complex spectrum_sitar_voice[WIN_SIZE];

    // temp variables:
    polar temp_polar_mic, temp_polar_synth, temp_polar_sitar;
    
   fun void listen()
   {
       //spork ~sitar_voice();
       spork ~osc_voice();
       spork ~pit_bend();
    
        while(true)
        {
               fft_mic.upchuck(); // take mic fft
               fft_synth.upchuck(); // take synth fft
               fft_sitar.upchuck();
               fft_mic.spectrum(spectrum_mic); // retrieve results of mic transform
               fft_synth.spectrum(spectrum_synth); // retrieve results of synth transform
               fft_sitar.spectrum(spectrum_sitar); // retrieve results of synth transform
                
               // for each value in the mic transform result, convert it from complex to
               // polar, apply it to the synth transform, and convert it back to complex:
               for( 0 => int i; i < spectrum_mic.cap(); i++ ) 
               {
                   spectrum_mic[i]$polar => temp_polar_mic;
                   spectrum_synth[i]$polar => temp_polar_synth;
                   spectrum_sitar[i]$polar => temp_polar_sitar;
                   temp_polar_mic.mag => temp_polar_synth.mag; // apply magnitude of mic to synth
                   temp_polar_sitar.mag => temp_polar_mic.mag;
                   temp_polar_synth$complex => spectrum_synth[i]; // store result in altered synth transform
                   temp_polar_mic$complex   => spectrum_mic[i];
               }
               
                env.keyOn();
               
                ifft.transform(spectrum_synth); // take inverse transform of our new altered synth transform
                ifft.transform(spectrum_mic);
                HOP_SIZE::samp => now;
        }
   }
    fun void sitar_voice()
    {
        
        while(true)
        {
            if(requestNote == true)
            {
                osc.freq(osc_freq);
                osc_freq => sit.freq;
                sit.noteOn(0.5);
                sit.pluck(osc_freq);
                1::second => now;
            }
        }
            
    }
       
    fun void osc_voice()
    {
        Hid hi2;
        HidMsg msg2;
        0 => int device2;
        if( me.args() ) me.arg(0) => Std.atoi => device2;
        if( !hi2.openKeyboard( device2 ) ) me.exit();
            
        while(true)
        {
           hi2 => now;
           while( hi2.recv(msg2) )
           {
                if(msg2.isButtonDown())
                {
                   true => requestNote;
                   Math.random2(0, 3) => int randm;
                   Std.mtof(mel[randm]) => osc.freq;
                   1 => osc.gain;
                   HOP_SIZE::samp => now;
                }

                else if( msg2.isButtonUp() )
                {
                   false => requestNote;
                   0.0 => osc.gain;
                   HOP_SIZE::samp => now;
                }
           }
        }
    }

    fun void pit_bend()
    {
        Hid hi;
        HidMsg msg;
        0 => int device;
        if( me.args() ) me.arg(0) => Std.atoi => device;
        if( !hi.openMouse( device ) ) me.exit();
            
       while(true)
       {
           hi => now;
           while( hi.recv(msg) )
           {
                if(msg.isButtonDown())
                {
                   true => requestPitch; 
                }
                
                else if(msg.isWheelMotion() && requestPitch == true)
                {
                    msg.deltaY * .003 + shift => shift;
                    shift => pit.shift;
                }

                else if( msg.isButtonUp() )
                {
                   false => requestPitch;
                   0.0 => pit.shift => shift;
                }
           }
       }
        
    }
}



    

