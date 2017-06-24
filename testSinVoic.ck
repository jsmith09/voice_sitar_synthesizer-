SintarVoic voic => dac;

while(true)
{
    Std.mtof(Math.random2(60,78)) => voic.setFreq;  
    voic.playOn();
    

}