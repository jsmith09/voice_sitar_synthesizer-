SndBuf buf => FFT fft_mic => blackhole;
SqrOsc osc => FFT fft_synth => blackhole;
Sitar sit => FFT fft_sitar => dac;
IFFT ifft => Chorus chor => dac;
IFFT ifft_sitar => dac;

me.dir()+"/audio/robgrace.wav" => buf.read;

1 => buf.gain;


// fft/ifft constants
3000 => int FFT_SIZE => fft_mic.size => fft_synth.size => fft_sitar.size => ifft.size => ifft_sitar.size;
FFT_SIZE/2 => int WIN_SIZE;
WIN_SIZE/2 => int HOP_SIZE;

//Filter and Envelop Set up

//Effects 
10 => chor.mix;
0.6 => chor.modDepth;

//Sitar setup
float osc_freq;


// windowing:
Windowing.hann(WIN_SIZE) => fft_mic.window => fft_synth.window => fft_sitar.window => ifft.window => ifft_sitar.window;

// spectrum array:
complex spectrum_synth[WIN_SIZE];
complex spectrum_mic[WIN_SIZE];
complex spectrum_sitar[WIN_SIZE];
complex spectrum_sitar_voice[WIN_SIZE];

// temp variables:
polar temp_polar_mic, temp_polar_synth, temp_polar_sitar;

//1 => buf.loop;
spork ~sitar_voice();
spork ~osc_voice();
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
       
        ifft.transform(spectrum_synth); // take inverse transform of our new altered synth transform
        ifft.transform(spectrum_mic);
        HOP_SIZE::samp => now;
}

fun void sitar_voice()
{
    while(true)
    {
        osc.freq(osc_freq);
        osc_freq => sit.freq;
        sit.noteOn(0.5);
        sit.pluck(osc_freq);
        1::second => now;
    }
        
}
   
fun void osc_voice()
{
    while(true)
    {
        Std.mtof(60) => osc.freq;
        HOP_SIZE::samp => now;
    }
}




    

