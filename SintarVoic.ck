// @title Voxbox.ck (MUSIC 220A FINAL PROJECT)
// @author Gio Jacuzzi (gjacuzzi@stanford.edu)
// 
// @desc
//    Voxbox is a vocoder made from two components: a synthesizer and a controller.
// The synthesizer is created from a modified Triangle Oscillator in ChucK. 5 voices of
// the synthesizer are created, so in effect there are 5 TriOsc unit-generators running in
// parallel. The controller, on the other hand, is a java-based swing application that
// communicates with ChucK in real-time via OSC and alters the parameters of the output signal
// and calls on one or more of these voices to sound.
//    Voxbox takes in the user's mic input, applies a Fast Fourier Transform, and stores the
// resulting data array in a spectrum. Simultaenously, the output from the user-controlled
// synthesizer is routed through another FFT, and the resulting data array is again stored in
// a separate spectrum. The spectrum from the mic input is then mapped to that of the synthesizer
// input, and the resulting array is passed through an IFFT to the output, which essentially does
// the FFT processing in reverse, creating a new modified sound singal based on the data from the
// mic and synth analyses.
//    All of this processing happens continuously while ChucK listens for OSC messages as input,
// and alters the parameters of effects and filters daisy-chained through the output in response.
// When a musical key is pressed from the controller, ChucK goes to one of the 5 voices, adjusts
// it's oscillation frequency to the frequency matching the musical key, and then routes the oscillator's
// output signal to the main output signal. Then, when the musical key is lifted, the oscillator's output
// signal is removed from the main output signal, and the voice waits silently until it is called
// on again.
//
// @note The code for the FFT processing was adapted from a small open-source example
//  that Senior Software Engineer (Dolby Laboratories) Eduard Aylon shared on Princeton
//  University's [chuck-users] public mailing list. The thread can be found here:
//  <https://lists.cs.princeton.edu/pipermail/chuck-users/2007-October/002211.html>
// @version chuck-1.3.2.0
// ----------------------------------------------------------------------------------

//=INPUT=============================================================================
Gain line_synth => FFT fft_synth => blackhole; // input-synth signal
adc.left => PoleZero dcblock_mic => FFT fft_mic => blackhole; // input-mic signal
//=OUTPUT============================================================================
IFFT ifft_output => PoleZero dcblock_output => PitShift shift => Chorus chorus => LPF filter_lpf => HPF filter_hpf => JCRev reverb => Echo echo => Gain output => dac; // output signal

// unit-generator initial values
0.5 => output.gain;
0.5 => line_synth.gain;
filter_lpf.freq(0.999 * 10000);
filter_hpf.freq(0.001 * 10000);

// effect initial values
reverb.mix(0.0);
echo.mix(0.0);
chorus.mix(0.0);
chorus.modDepth(0.0);
chorus.modFreq(0.0);
//vibrato.vibratoRate(0.0); buggy
//vibrato.vibratoGain(0.5); buggy
//vibrato.randomGain(0.0); buggy
shift.mix(1.0);
shift.shift(1.0);

// both of these one-pole one-zero filters remove "zero-frequency components"
// from the signal. This allows the output to be louder without distortion.
0.999 => dcblock_mic.blockZero;
0.999 => dcblock_output.blockZero;

// constant values for fft_synth, fft_mic, and ifft_output
600 => int FFT_SIZE => fft_synth.size => fft_mic.size => ifft_output.size;
FFT_SIZE => int WIN_SIZE;
FFT_SIZE/32 => int HOP_SIZE;

// generate a Hann window for use with fft_mic, fft_synth, and ifft_output
Windowing.hann(WIN_SIZE) => fft_mic.window => fft_synth.window => ifft_output.window;

complex spectrum_synth[WIN_SIZE/2]; // spectrum array for synth transform
complex spectrum_mic[WIN_SIZE/2]; // spectrum array for mic transform
polar temp_polar_mic, temp_polar_synth; // temp variables for complex to polar conversion

//-VOCODER PROCESSING---------------------------------------------------------------
fun void vocode_filter() {
    while( true ) {
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
        ifft_output.transform(spectrum_synth); // take inverse transform of our new altered synth transform
        HOP_SIZE::samp => now;
    }
}
//----------------------------------------------------------------------------------

spork ~vocode_filter(); // run the vocoder

//-SYNTH PROCESSING-----------------------------------------------------------------
fun void synthvoice() {
    TriOsc voice;
    float note;
    while (true) {
        on => now;
        <<< "NoteOn" >>>;
        on.note => note;
        note => voice.freq;
        1.0 => voice.gain;
        voice => line_synth;
        
        off => now;
        <<< "NoteOff" >>>;
        0.0 => voice.gain;
        voice =< line_synth;
    }
}

spork ~synthvoice(); // run each voice of the synth
