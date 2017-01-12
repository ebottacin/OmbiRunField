class OmniRunFieldApp extends Toybox.Application.AppBase {
	
    function initialize() {
        AppBase.initialize();
    }

    //! Return the initial view of your application here
    function getInitialView() {
        return [ new OmniRunFieldView() ];
    }
}


class OmniRunFieldView extends Toybox.WatchUi.DataField {

	hidden var uHrZones = [ 93, 111, 130, 148, 167, 185 ];
	hidden var unitP = 1000.0;
	hidden var unitD = 1000.0;


	hidden var mTimerRunning = false;
	hidden var mIntervalType = 0;
	//! 0 - interval not set
	//! 1 - interval
	//! -1 - rest
	
	hidden static const BUFFER_SIZE = 5;
	hidden var mSpeedQueue          = null;

	hidden var mLaps 					 = 1;
	hidden var mLastLapDistMarker 		 = 0;
    hidden var mLastLapTimeMarker 		 = 0;

	hidden var mLastLapTimerTime 		= 0;
	hidden var mLastLapElapsedDistance 	= 0;
	hidden var mCurrentLapIntervalType  = 0;
	
	hidden var uMinIntervalPaceSecDiff = 45; 
	
	hidden var mTicker 		= 0;
	hidden var mLapTicker	= 0;

	

    function initialize() {
        DataField.initialize();

        var mProfile = UserProfile.getProfile();
        if (mProfile != null) {
	 		uHrZones = UserProfile.getHeartRateZones(UserProfile.getCurrentSport());
 		}

 		var mApp = Application.getApp();
 		uMinIntervalPaceSecDiff = mApp.getProperty("pMinIntervalPaceInSecondsDiff");
 		
		mSpeedQueue = new[BUFFER_SIZE];
		
        if (System.getDeviceSettings().paceUnits == System.UNIT_STATUTE) {
        	unitP = 1609.344;
        }

        if (System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE) {
        	unitD = 1609.344;
        }
    }


    //! Calculations we need to do every second even when the data field is not visible
    function compute(info) { 	
    	if (mTimerRunning) {  //! We only do calculations if the timer is running
    		mTicker++;
	        mLapTicker++;
    	}
    }

    //! Store last lap quantities and set lap markers
    function onTimerLap() {
    	var info = Activity.getActivityInfo();

    	mLastLapTimerTime			= (info.timerTime - mLastLapTimeMarker) / 1000;
    	mLastLapElapsedDistance		= (info.elapsedDistance != null) ? info.elapsedDistance - mLastLapDistMarker : 0;
		
    	mLapTicker = 0;
    	
    	mLastLapDistMarker 			= info.elapsedDistance;
    	mLastLapTimeMarker 			= info.timerTime;
    	mCurrentLapIntervalType     = 0;   	
    }

    //! Timer transitions from stopped to running state
    function onTimerStart() {
    	mTimerRunning = true;
    }


    //! Timer transitions from running to stopped state
    function onTimerStop() {
    	mTimerRunning = false;
    }


    //! Timer transitions from paused to running state (i.e. resume from Auto Pause is triggered)
    function onTimerResume() {
    	mTimerRunning = true;
    }


    //! Timer transitions from running to paused state (i.e. Auto Pause is triggered)
    function onTimerPause() {
    	mTimerRunning = false;
    }


    //! Current activity is ended
    function onTimerReset() {
	   
		mLaps 					  = 1;
		mLastLapDistMarker 		  = 0;
	    mLastLapTimeMarker 		  = 0;
	    
		mLastLapTimerTime 			= 0;
		mLastLapElapsedDistance 	= 0;
				
		mTicker 	= 0;
		mLapTicker	= 0;
		
		for (var i=0; i<BUFFER_SIZE; i++) {
			mSpeedQueue[i]=null;
		}
    }


    //! Do necessary calculations and draw fields.
    //! This will be called once a second when the data field is visible.
    function onUpdate(dc) {
    	var info = Activity.getActivityInfo();
		
		//System.println ("mLastLapTimeMarker: " + mLastLapTimeMarker + ", mLastLapDistMarker: " + mLastLapDistMarker);
		
		var mBgColour;
    	var mColour;

    	//! Calculate lap distance
    	var mLapElapsedDistance = 0.0;
    	if (info.elapsedDistance != null) {
			mLapElapsedDistance = info.elapsedDistance - mLastLapDistMarker;
    	}

    	//! Calculate lap time and convert timers from milliseconds to seconds
    	var mTimerTime = 0;
    	var mLapTimerTime = 0;

    	if (info.timerTime != null) {
			mTimerTime = info.timerTime / 1000;
    		mLapTimerTime = (info.timerTime - mLastLapTimeMarker) / 1000;
    	}
    	
		//System.println ("mLapTimerTime: " + mLapTimerTime + ", mLapElapsedDistance: " + mLapElapsedDistance);
    	
    	//! Calculate lap speeds
    	var mLapSpeed = 0.0;
    	var mLastLapSpeed = 0.0;    	
    	if (mLapTimerTime > 0 && mLapElapsedDistance > 0) {
    		mLapSpeed = mLapElapsedDistance / mLapTimerTime;
    	}
    	if (mLastLapTimerTime > 0 && mLastLapElapsedDistance > 0) {
    		mLastLapSpeed = mLastLapElapsedDistance / mLastLapTimerTime;
    	}
	
		//check interval every 10 seconds
		if (mLapTicker>0 && (mLapTicker % 10)==0 && mLapSpeed > 0 && mLastLapSpeed > 0) {
			var diff = (unitP/mLapSpeed) - (unitP/mLastLapSpeed);
			//System.println ("mLapSpeed : " + (unitP/mLapSpeed) + ", mLastLapSpeed: " + (unitP/mLastLapSpeed) + ", diff: " + diff);
			if (diff*-1> uMinIntervalPaceSecDiff) {
				mIntervalType = 1;
				if (mCurrentLapIntervalType == 0 ) {
					mCurrentLapIntervalType = 1;
					mLaps++;
				}
			} else if  (diff> uMinIntervalPaceSecDiff) {
				mIntervalType = -1;
			} else {
				mIntervalType = 0;
				if (mCurrentLapIntervalType == 1 ) {
					mCurrentLapIntervalType = 0;
					mLaps--;
				}
			}
		}
		
     	//!
    	//! Draw colour indicators
		//!

		//! HR zone
    	mColour = Graphics.COLOR_LT_GRAY; //! No zone default light grey
    	var mCurrentHeartRate = "--";
    	if (info.currentHeartRate != null) {
    		mCurrentHeartRate = info.currentHeartRate;
			if (uHrZones != null) {
				if (mCurrentHeartRate >= uHrZones[4]) {
					mColour = Graphics.COLOR_RED;		//! Maximum (Z5)
				} else if (mCurrentHeartRate >= uHrZones[3]) {
					mColour = Graphics.COLOR_ORANGE;	//! Threshold (Z4)
				} else if (mCurrentHeartRate >= uHrZones[2]) {
					mColour = Graphics.COLOR_GREEN;		//! Aerobic (Z3)
				} else if (mCurrentHeartRate >= uHrZones[1]) {
					mColour = Graphics.COLOR_BLUE;		//! Easy (Z2)
				} //! Else Warm-up (Z1) and no zone both inherit default light grey here
			}
    	}
		dc.setColor(mColour, Graphics.COLOR_TRANSPARENT);
		dc.fillRectangle(0, 53, 63, 17);		

		mColour = Graphics.COLOR_LT_GRAY;
		if (info.currentCadence != null) {
			if (info.currentCadence > 183) {
				mColour = Graphics.COLOR_PURPLE;
			} else if (info.currentCadence >= 174) {
				mColour = Graphics.COLOR_BLUE;
			} else if (info.currentCadence >= 164) {
				mColour = Graphics.COLOR_GREEN;
			} else if (info.currentCadence >= 153) {
				mColour = Graphics.COLOR_ORANGE;
			} else if (info.currentCadence >= 120) {
				mColour = Graphics.COLOR_RED;
			} //! Else no cadence or walking/stopped inherits default light grey here
		}
		dc.setColor(mColour, Graphics.COLOR_TRANSPARENT);
		dc.fillRectangle(142, 53, 63, 17);
		

		//! Current pace vs target pace colour indicator
		mColour = Graphics.COLOR_LT_GRAY;
		if (info.currentSpeed != null) {	//! Only use the pace colour indicator when running (1.8 m/s = 9:15 min/km, ~15:00 min/mi)
			var mTargetSpeed = 0.0;
			if (mLapSpeed > 0) {
				var paceDeviation = (info.currentSpeed / mLapSpeed);
				if (paceDeviation < 0.95) {	//! More than 5% slower
					mColour = Graphics.COLOR_RED;
				} else if (paceDeviation <= 1.05) {	//! Within +/-5% of target pace
					mColour = Graphics.COLOR_GREEN;
				} else {  //! More than 5% faster
					mColour = Graphics.COLOR_BLUE;
				}
			}
		}
		dc.setColor(mColour, Graphics.COLOR_TRANSPARENT);
		dc.fillRectangle(63, 53, 79, 17);
		
		if (mIntervalType==0) {
			mBgColour = Graphics.COLOR_DK_GRAY;
		} else if  (mIntervalType == 1) {
			mBgColour = Graphics.COLOR_RED;
		} else {
			mBgColour = Graphics.COLOR_DK_BLUE;
		}
		
		dc.setColor(mBgColour, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
		
		if (mIntervalType==0) {
			//! Top vertical divider
			dc.drawLine(102, 0, 102, 53);
		} else {
			//do not render lap counter in normal mode
			//! Top vertical divider
			dc.drawLine(102, 26, 102, 53);
			//! Top centre mini-field separator
			dc.drawRoundedRectangle(87, -10, 32, 36, 4);
		}
		
		 
        //! Horizontal thirds
		dc.drawLine(0, 52, 215, 52);
		dc.drawLine(0, 110, 215, 110);
    	
    	//! Centre vertical dividers
		dc.drawLine(63, 53, 63, 110);
		dc.drawLine(142, 53, 142, 110);
    	
		//! Bottom vertical divider
		dc.drawLine(102, 110, 102, 148);

		mBgColour = (getBackgroundColor() == Graphics.COLOR_BLACK) ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;

		//! Set text colour
        dc.setColor(mBgColour, Graphics.COLOR_TRANSPARENT);

        //!
        //! Draw field values
        //! =================
        //!        

		//! Top row left: time
		var mTime;
		var lTime;
		//! Top row right: distance
		var mDistance;
		var lDistance;
		if (mIntervalType != 0) {
        	//! Lap counter
			dc.drawText(102, 0, Graphics.FONT_NUMBER_MILD, mLaps, Graphics.TEXT_JUSTIFY_CENTER);
			mTime = mLapTimerTime;
			lTime = "Lap Time";
			mDistance = mLapElapsedDistance / unitD;
			lDistance = "Lap Dist.";
		} else {
			mTime = mTimerTime;
			lTime = "Timer";
			mDistance = (info.elapsedDistance != null) ? info.elapsedDistance / unitD : 0;
			lDistance = "Distance";
		}
		
		var fTimerSecs = (mTime % 60).format("%02d");
		var fTimer = (mTime / 60).format("%d") + ":" + fTimerSecs;  //! Format time as m:ss
		var x = 45;        
    	if (mTime > 3599) {
    		//! (Re-)format time as h:mm(ss) if more than an hour
    		fTimer = (mTime / 3600).format("%d") + ":" + (mTime / 60 % 60).format("%02d");
    		x = 32;
			dc.drawText(62, 26, Graphics.FONT_NUMBER_MILD, fTimerSecs, Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);
		}
		dc.drawText(x, 32, Graphics.FONT_NUMBER_MEDIUM, fTimer, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		dc.drawText(44, 6, Graphics.FONT_XTINY,  lTime, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);

		var fString = "%.2f";
	 	if (mDistance > 100) {
	 		fString = "%.1f";
	 	}
		dc.drawText(161, 32, Graphics.FONT_NUMBER_MEDIUM, mDistance.format(fString), Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		dc.drawText(161, 6, Graphics.FONT_XTINY,  lDistance, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		
		//! Centre middle: current pace
		if (info.currentSpeed == null || info.currentSpeed < 0.447164 || !mTimerRunning) {
			drawSpeedUnderlines(dc, 102, 89);
		} else {	
			var fCurrentPace;
			mSpeedQueue[(mLapTicker-1)%BUFFER_SIZE]=info.currentSpeed;
			var avg=0;
			var num=0;
			for (var i=0; i<BUFFER_SIZE;i++) {
				if (mSpeedQueue[i]!=null) {
			    	avg += mSpeedQueue[i];
			    	num++; 
			    }
			}
			fCurrentPace = avg/ num;
			dc.drawText(102, 90, Graphics.FONT_NUMBER_MEDIUM, fmtPace(fCurrentPace), Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		}
		dc.drawText(102, 60, Graphics.FONT_XTINY,  "Pace", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);

		//! Centre left: heart rate
		dc.drawText(31, 90, Graphics.FONT_NUMBER_MEDIUM, mCurrentHeartRate, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		dc.drawText(31, 60, Graphics.FONT_XTINY, "HR", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);

		//! Centre right: cadence 
		var fCentre = (info.currentCadence != null) ? info.currentCadence : 0;
		var lCentre = "Cadence";
		dc.drawText(174, 90, Graphics.FONT_NUMBER_MEDIUM, fCentre, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		dc.drawText(174, 60, Graphics.FONT_XTINY, lCentre, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);

		//! Bottom left
		var fieldValue = mLapSpeed;
		var fieldLabel = "Lap";
		
		if (fieldValue < 0.447164) {
			drawSpeedUnderlines(dc, 63, 128);
		} else {
			dc.drawText(63, 130, Graphics.FONT_NUMBER_MEDIUM, fmtPace(fieldValue), Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		}
		dc.drawText(1, 118, Graphics.FONT_XTINY, fieldLabel, Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);

		//! Bottom right
		if (mIntervalType != 0) {
			fieldLabel = "Time";
		    x= 142;
			if (mTime > 3599) {
	    		//! (Re-)format time as h:mm(ss) if more than an hour
	    		x = 131;
				dc.drawText(160, 125, Graphics.FONT_NUMBER_MILD, fTimerSecs, Graphics.TEXT_JUSTIFY_LEFT|Graphics.TEXT_JUSTIFY_VCENTER);
			}
			dc.drawText(x, 130, Graphics.FONT_NUMBER_MEDIUM, fTimer, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
		} else {
			fieldLabel = "L-1";
			if (mLastLapSpeed < 0.447164) {
				drawSpeedUnderlines(dc, 142, 128);
			} else {
				dc.drawText(142, 130, Graphics.FONT_NUMBER_MEDIUM, fmtPace(mLastLapSpeed), Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
			}
		}

		dc.drawText(203, 118, Graphics.FONT_XTINY, fieldLabel, Graphics.TEXT_JUSTIFY_RIGHT|Graphics.TEXT_JUSTIFY_VCENTER);

    }


    function fmtPace(secs) {
    	var s = (unitP/secs).toLong();
        return (s / 60).format("%0d") + ":" + (s % 60).format("%02d");
    }


    function drawSpeedUnderlines(dc, x, y) {
    	var y2 = y + 18;
        dc.setPenWidth(1);
    	dc.drawLine(x - 37, y2, x - 21, y2);
		dc.drawLine(x - 20, y2, x - 4,  y2);
		dc.drawLine(x + 4,  y2, x + 20, y2);
		dc.drawLine(x + 21, y2, x + 37, y2);
		dc.drawText(x, y, Graphics.FONT_NUMBER_MEDIUM, ":", Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
