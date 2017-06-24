adc => FFT fft_mic => blackhole;
VoicForm tri => FFT fft_synth => blackhole;
IFFT ifft => dac;
Sitar sit => dac;

//me.dir()+"/audio/robgrace.wav" => buf.read;

//1 => buf.gain;

// fft/ifft constants
3000 => int FFT_SIZE => fft_mic.size => fft_synth.size => ifft.size;
FFT_SIZE/2 => int WIN_SIZE;
WIN_SIZE/2 => int HOP_SIZE;



// windowing:
Windowing.hann(WIN_SIZE) => fft_mic.window => fft_synth.window => ifft.window;

// spectrum array:
complex spectrum_synth[WIN_SIZE];
complex spectrum_mic[WIN_SIZE];

// temp variables:
polar temp_polar_mic, temp_polar_synth;

//1 => buf.loop;


while( true )
{
     // take ffts:
        fft_mic.upchuck(); // take mic fft
        fft_synth.upchuck(); // take synth fft
        fft_mic.spectrum(spectrum_mic); // retrieve results of mic transform
        <<<spectrum_mic>>>;
        fft_synth.spectrum(spectrum_synth); // retrieve results of synth transform
        
        // for each value in the mic transform result, convert it from complex to
        // polar, apply it to the synth transform, and convert it back to complex:
        for( 0 => int i; i < spectrum_mic.cap(); i++ ) {
            spectrum_mic[i]$polar => temp_polar_mic;
            spectrum_synth[i]$polar => temp_polar_synth;
            temp_polar_mic.mag => temp_polar_synth.mag; // apply magnitude of mic to synth
            temp_polar_synth$complex => spectrum_synth[i]; // store result in altered synth transform
        }
        ifft.transform(spectrum_synth); // take inverse transform of our new altered synth transform
        HOP_SIZE::samp => now;
}


fun void sintar_voice()
{
    while (true) 
    {
        Std.mtof(40) => tri.freq;
        tri.pitchSweepRate(60);
        tri.vibratoFreq(60);
        1.0 => tri.gain;
        HOP_SIZE::samp => now;
    }
    
}
spork ~sintar_voice();
    

