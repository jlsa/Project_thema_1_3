import javax.swing.*;
import java.awt.event.*;
import java.awt.*;
import sun.audio.*;
import java.io.*;

public class MultisegmentPanel extends JFrame {
    private static final long serialVersionUID = 1L;
    private Multisegment ms;
    private boolean[][] bSeg;
    private final int W=1300;
    private final int H=600;
	
    public MultisegmentPanel(Multisegment ms) {
	this.ms=ms;
	// set up internal rep
	bSeg=new boolean[7][];
	for(int i=0;i<6;i++) {
	    bSeg[i]=new boolean[7];			
	}
	bSeg[6]=new boolean[5];

	setSize(W,H);
	setVisible(true);  
	setResizable(false);  

	addWindowListener(new WindowAdapter() {
		public void windowClosing(WindowEvent e) {
		    exit();
		}
	    });

	showAll();
    }
	
    public void setAll(byte[] b) {
	for(int i=0;i<6;i++)
	    setSegment(b[i], i);
	setSpecial(b[6]);
	repaint();
    }	
	
    private void setSegment(byte b, int pos) {
	int i=0;
	while(i<7) {
	    bSeg[pos][i]=((b&1)==1);
	    b>>=1;
	    i++;
	}		
    }
	
    private void setSpecial(byte b) {
	int i=0;
	while(i<5) {
	    bSeg[6][i]=((b&1)==1);
	    b>>=1;
	    i++;
	}		
    }
	
    public void clearAll() {
	for(int i=0;i<6;i++) 
	    setSegment((byte)0x00, i);
	setSpecial((byte)0x00);
	repaint();
    }

    // show all display elements
    public void showAll() {
	for(int i=0;i<6;i++) 
	    setSegment((byte)0xff, i);
	setSpecial((byte)0xff);
	repaint();
    }

    private void exit() {
	System.exit(0);
    }
	
    public void paint(Graphics g) {
	g.setColor(new Color(242,242,242)); // grey
	g.fillRect(0, 0, W, H);
	g.setColor(new Color(119,147,60)); // green
	for(int i=0;i<6;i++) {
	    drawSegment(g,bSeg[i], i);
	}
	g.setFont(new Font("", Font.BOLD, 14));
	drawSpecial(g);
    }
	
    private void drawSegment(Graphics g,boolean[] b, int pos) {
	int xBase=pos*110+290;
	if (pos>1 && pos <=3) xBase+=40;
	if (pos>3) xBase+=80;
	int yBase=160;
	int xL=80;
	int yL=100;
	int xTol=10;
	int yTol=10;
		
	if (b[0]) 
	    g.fillRoundRect(xBase, yBase, xL, yTol, 5, 5);
		
	if (b[1]) 
	    g.fillRoundRect(xBase-xTol, yBase+yTol, xTol, yL, 5, 5);

	if (b[2]) 
	    g.fillRoundRect(xBase+xL, yBase+yTol, xTol, yL, 5, 5);

	if (b[3]) 
	    g.fillRoundRect(xBase, yBase+yL+yTol, xL, yTol, 5, 5);
		
	if (b[4]) 
	    g.fillRoundRect(xBase-xTol, yBase+yL+2*yTol, xTol, yL, 5, 5);

	if (b[5]) 
	    g.fillRoundRect(xBase+xL, yBase+yL+2*yTol, xTol, yL, 5, 5);

	if (b[6]) 
	    g.fillRoundRect(xBase, yBase+2*yTol+2*yL, xL, yTol, 5, 5);
    }
	
    private void drawSpecial(Graphics g) {
	if (bSeg[6][0]) // alarm indicator
	    g.drawString("ALARM", 1030, 170);
		
	if (bSeg[6][1]) // second colon
	    drawColon(g,1);
		
	if (bSeg[6][2]) // first colon
	    drawColon(g,0);
		
	if (bSeg[6][3]) // sound alarm buzzer
	    AlarmBuzzer();
    } 
	
    private void drawColon(Graphics g, int pos) {
	int X=507+pos*260;
	int Y=228;
	g.fillOval(X, Y, 20, 20);
	Y+=60;
	g.fillOval(X, Y, 20, 20);
    }
	
    private void AlarmBuzzer() {
	AudioStream as = null;
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

	// wait 1 sec
	try {
	    Thread.sleep(1000);  
	} catch (InterruptedException e) {
	    e.printStackTrace();
	}
	AudioPlayer.player.stop(as);
    }
}
