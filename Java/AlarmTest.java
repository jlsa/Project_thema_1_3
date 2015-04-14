import sun.audio.*;
import java.io.*;

public class AlarmTest {
private long lastAlarm;
private AudioStream as;

public AlarmTest() {
as = null;
long lastAlarm = 0;
boolean alarm = true;
int count = 0;
while(alarm) {
if(count >= 60) {
	alarm = false;
	stopAlarm();
}
if(System.currentTimeMillis() - 5975 >= lastAlarm) {
	lastAlarm = System.currentTimeMillis();
	playAlarm();
}
}
}

public static void main(String[] args) {
new AlarmTest();
}
	
	/**
	 * Plays the "alarm.wav" file.
	 */
	private void playAlarm() {
		as = null;
		try {
			// Open an input stream  to the audio file.
			InputStream in = new FileInputStream("alarm.wav");
			// Create an AudioStream object from the input stream.
			as = new AudioStream(in);         
		} catch (IOException e) {
			e.printStackTrace();
		}
		// Use the static class member "player" from class AudioPlayer to play clip
		AudioPlayer.player.start(as);   
	}
	
	/**
	 * Stops the alarm sound if it is playing.
	 */
	private void stopAlarm() {
		if(as != null)
		AudioPlayer.player.stop(as);
	}
}