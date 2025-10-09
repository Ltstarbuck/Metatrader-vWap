//+------------------------------------------------------------------+
//|                                                    VWAP_Lite.mq5 |
//|                     Copyright 2016, SOL Digital Consultoria LTDA |
//|                          http://www.soldigitalconsultoria.com.br |
//+------------------------------------------------------------------+
#property copyright         "Copyright 2016, SOL Digital Consultoria LTDA"
#property link              "http://www.soldigitalconsultoria.com.br"
#property version           "1.5"

#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4

#property indicator_label1  "VWAP Daily"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_DASH
#property indicator_width1  2

#property indicator_label2  "VWAP Weekly"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_DASH
#property indicator_width2  2

#property indicator_label3  "VWAP Monthly"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGreen
#property indicator_style3  STYLE_DASH
#property indicator_width3  2

#property indicator_label4  "VWAP Yearly"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrMagenta
#property indicator_style4  STYLE_DASH
#property indicator_width4  2

enum DATE_TYPE {
    DAILY,
    WEEKLY,
    MONTHLY,
    YEARLY
};

enum PRICE_TYPE {
    OPEN,
    CLOSE,
    HIGH,
    LOW,
    OPEN_CLOSE,
    HIGH_LOW,
    CLOSE_HIGH_LOW,
    OPEN_CLOSE_HIGH_LOW
};

datetime CreateDateTime(DATE_TYPE nReturnType = DAILY, datetime dtDay = D'2000.01.01 00:00:00', int pHour = 0, int pMinute = 0, int pSecond = 0) {
    datetime    dtReturnDate;
    MqlDateTime timeStruct;

    TimeToStruct(dtDay, timeStruct);
    timeStruct.hour = pHour;
    timeStruct.min  = pMinute;
    timeStruct.sec  = pSecond;
    dtReturnDate = (StructToTime(timeStruct));

    if(nReturnType == WEEKLY) {
        while (timeStruct.day_of_week != 0) {
            dtReturnDate = (dtReturnDate - 86400);
            TimeToStruct(dtReturnDate, timeStruct);
        }
    }

    if(nReturnType == MONTHLY) {
        timeStruct.day = 1;
        dtReturnDate = (StructToTime(timeStruct));
    }

    if(nReturnType == YEARLY) {
        timeStruct.mon = 1;
        timeStruct.day = 1;
        dtReturnDate = (StructToTime(timeStruct));
    }

    return dtReturnDate;
}

sinput  string      Indicator_Name      = "Volume Weighted Average Price (VWAP)";
input   PRICE_TYPE  Price_Type          = CLOSE_HIGH_LOW;
input   bool        Calc_Every_Tick     = false;
input   bool        Enable_Daily        = true;
input   bool        Show_Daily_Value    = true;
input   bool        Enable_Weekly       = false;
input   bool        Show_Weekly_Value   = false;
input   bool        Enable_Monthly      = false;
input   bool        Show_Monthly_Value  = false;
input   bool        Enable_Yearly       = false;
input   bool        Show_Yearly_Value   = false;
input   bool        Show_Countdown      = true;        // Show candlestick closing countdown
input   bool        Enable_Alert       = true;       // Enable VWAP crossover alert
input   bool        Alert_On_Daily     = true;        // Daily VWAP alert
input   bool        Alert_On_Weekly    = false;       // Weekly VWAP alert
input   bool        Alert_On_Monthly   = false;       // Monthly VWAP alert
input   bool        Alert_On_Yearly    = false;       // Yearly VWAP alert

double          VWAP_Buffer_Daily[], VWAP_Buffer_Weekly[], VWAP_Buffer_Monthly[], VWAP_Buffer_Yearly[];
double          nPriceArr[], nTotalTPV[], nTotalVol[];
double          nSumDailyTPV = 0, nSumWeeklyTPV = 0, nSumMonthlyTPV = 0, nSumYearlyTPV = 0;
double          nSumDailyVol = 0, nSumWeeklyVol = 0, nSumMonthlyVol = 0, nSumYearlyVol = 0;
int             nIdxDaily = 0, nIdxWeekly = 0, nIdxMonthly = 0, nIdxYearly = 0, nIdx = 0;
bool            bIsFirstRun = true;
string          sDailyStr = "", sWeeklyStr  = "", sMonthlyStr = "", sYearlyStr = "";
datetime        dtLastDay = CreateDateTime(DAILY), dtLastWeek = CreateDateTime(WEEKLY), dtLastMonth = CreateDateTime(MONTHLY), dtLastYear = CreateDateTime(YEARLY);
ENUM_TIMEFRAMES LastTimePeriod = PERIOD_MN1;
int             nStringYDistance = 40;
string          sCountdownStr = "";

// Alert status variables
bool            bAlertDaily = false;
bool            bAlertWeekly = false;
bool            bAlertMonthly = false;
bool            bAlertYearly = false;
datetime        dtLastAlertTime = 0;  // Last alert time

// VWAP crossover alert detection function
void CheckVWAPAlert(int currentBar, double &vwapBuffer[], bool &alertTriggered, string periodName, 
                    const double &open[], const double &high[], const double &low[], const double &close[]) {
    // Boundary condition check: ensure index is valid and VWAP value is valid
    if (currentBar <= 0 || currentBar >= ArraySize(vwapBuffer) || vwapBuffer[currentBar] == EMPTY_VALUE) return;
    
    double vwapValue = vwapBuffer[currentBar];
    
    // Get four key prices
    double prevClose = close[currentBar-1];  // Close price of the most recent closed candlestick
    double currOpen = open[currentBar];      // Open price of the current unclosed candlestick
    double currLow = low[currentBar];        // Low price of the current unclosed candlestick
    double currHigh = high[currentBar];      // High price of the current unclosed candlestick
    
    // Check if two price ranges contain VWAP
    bool range1ContainsVWAP = (prevClose <= vwapValue && currOpen >= vwapValue) || 
                              (prevClose >= vwapValue && currOpen <= vwapValue);
    
    bool range2ContainsVWAP = (currLow <= vwapValue && currHigh >= vwapValue);
    
    // If any price range contains VWAP, trigger alert
    if (!alertTriggered && (range1ContainsVWAP || range2ContainsVWAP)) {
        Alert(periodName + "VWAP Crossover Alert: " + _Symbol + 
              " Price range contains VWAP: " + DoubleToString(vwapValue, _Digits) +
              " Previous close: " + DoubleToString(prevClose, _Digits) +
              " Open price: " + DoubleToString(currOpen, _Digits) +
              " Low price: " + DoubleToString(currLow, _Digits) +
              " High price: " + DoubleToString(currHigh, _Digits));
        alertTriggered = true;
        dtLastAlertTime = TimeCurrent();
    }
}

int OnInit() {
    IndicatorSetInteger(INDICATOR_DIGITS,   _Digits);

    SetIndexBuffer(0, VWAP_Buffer_Daily,    INDICATOR_DATA);
    SetIndexBuffer(1, VWAP_Buffer_Weekly,   INDICATOR_DATA);
    SetIndexBuffer(2, VWAP_Buffer_Monthly,  INDICATOR_DATA);
    SetIndexBuffer(3, VWAP_Buffer_Yearly,   INDICATOR_DATA);

    if (Show_Daily_Value) {
        ObjectCreate(0, "VWAP_Daily", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, "VWAP_Daily",   OBJPROP_CORNER,     3);
        ObjectSetInteger(0, "VWAP_Daily",   OBJPROP_XDISTANCE,  180);
        ObjectSetInteger(0, "VWAP_Daily",   OBJPROP_YDISTANCE,  nStringYDistance);
        ObjectSetInteger(0, "VWAP_Daily",   OBJPROP_COLOR,      indicator_color1);
        ObjectSetInteger(0, "VWAP_Daily",   OBJPROP_FONTSIZE,   7);
        ObjectSetString (0, "VWAP_Daily",   OBJPROP_FONT,       "Verdana");
        ObjectSetString (0, "VWAP_Daily",   OBJPROP_TEXT,       " ");
        nStringYDistance = nStringYDistance + 20;
    }

    if (Show_Weekly_Value) {
        ObjectCreate(0, "VWAP_Weekly", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, "VWAP_Weekly",  OBJPROP_CORNER,     3);
        ObjectSetInteger(0, "VWAP_Weekly",  OBJPROP_XDISTANCE,  180);
        ObjectSetInteger(0, "VWAP_Weekly",  OBJPROP_YDISTANCE,  nStringYDistance);
        ObjectSetInteger(0, "VWAP_Weekly",  OBJPROP_COLOR,      indicator_color2);
        ObjectSetInteger(0, "VWAP_Weekly",  OBJPROP_FONTSIZE,   7);
        ObjectSetString (0, "VWAP_Weekly",  OBJPROP_FONT,       "Verdana");
        ObjectSetString (0, "VWAP_Weekly",  OBJPROP_TEXT,       " ");
        nStringYDistance = nStringYDistance + 20;
    }

    if (Show_Monthly_Value) {
        ObjectCreate(0, "VWAP_Monthly", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, "VWAP_Monthly", OBJPROP_CORNER,     3);
        ObjectSetInteger(0, "VWAP_Monthly", OBJPROP_XDISTANCE,  180);
        ObjectSetInteger(0, "VWAP_Monthly", OBJPROP_YDISTANCE,  nStringYDistance);
        ObjectSetInteger(0, "VWAP_Monthly", OBJPROP_COLOR,      indicator_color3);
        ObjectSetInteger(0, "VWAP_Monthly", OBJPROP_FONTSIZE,   7);
        ObjectSetString (0, "VWAP_Monthly", OBJPROP_FONT,       "Verdana");
        ObjectSetString (0, "VWAP_Monthly", OBJPROP_TEXT,       " ");
        nStringYDistance = nStringYDistance + 20;
    }

    if (Show_Yearly_Value) {
        ObjectCreate(0, "VWAP_Yearly", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, "VWAP_Yearly", OBJPROP_CORNER, 3);
        ObjectSetInteger(0, "VWAP_Yearly", OBJPROP_XDISTANCE, 180);
        ObjectSetInteger(0, "VWAP_Yearly", OBJPROP_YDISTANCE, nStringYDistance);
        ObjectSetInteger(0, "VWAP_Yearly", OBJPROP_COLOR, indicator_color4);
        ObjectSetInteger(0, "VWAP_Yearly", OBJPROP_FONTSIZE, 7);
        ObjectSetString (0, "VWAP_Yearly", OBJPROP_FONT, "Verdana");
        ObjectSetString (0, "VWAP_Yearly", OBJPROP_TEXT, " ");
        nStringYDistance = nStringYDistance + 20;
    }

    // Create countdown label (display above VWAP labels)
    if (Show_Countdown) {
        ObjectCreate(0, "KLine_Countdown", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, "KLine_Countdown", OBJPROP_CORNER, 3);
        ObjectSetInteger(0, "KLine_Countdown", OBJPROP_XDISTANCE, 180);
        ObjectSetInteger(0, "KLine_Countdown", OBJPROP_YDISTANCE, 20);  // Fixed at top position
        ObjectSetInteger(0, "KLine_Countdown", OBJPROP_COLOR, clrBlack);  // Use black color
        ObjectSetInteger(0, "KLine_Countdown", OBJPROP_FONTSIZE, 7);
        ObjectSetString (0, "KLine_Countdown", OBJPROP_FONT, "Verdana");
        ObjectSetString (0, "KLine_Countdown", OBJPROP_TEXT, "Candlestick Closing Countdown: ");
    }

    return(INIT_SUCCEEDED);
}

void OnDeinit(const int pReason) {
    if (Show_Daily_Value)   ObjectDelete(0, "VWAP_Daily");
    if (Show_Weekly_Value)  ObjectDelete(0, "VWAP_Weekly");
    if (Show_Monthly_Value) ObjectDelete(0, "VWAP_Monthly");
    if (Show_Yearly_Value)  ObjectDelete(0, "VWAP_Yearly");
    if (Show_Countdown)     ObjectDelete(0, "KLine_Countdown");
}

int OnCalculate(const int       rates_total,
                const int       prev_calculated,
                const datetime  &time[],
                const double    &open[],
                const double    &high[],
                const double    &low[],
                const double    &close[],
                const long      &tick_volume[],
                const long      &volume[],
                const int       &spread[]) {

    if (PERIOD_CURRENT != LastTimePeriod) {
        bIsFirstRun = true;
        LastTimePeriod = PERIOD_CURRENT;
    }

    if (rates_total > prev_calculated || bIsFirstRun || Calc_Every_Tick) {
        ArrayResize(nPriceArr, rates_total);
        ArrayResize(nTotalTPV, rates_total);
        ArrayResize(nTotalVol, rates_total);

        if (Enable_Daily)   {nIdx = nIdxDaily;   nSumDailyTPV = 0;   nSumDailyVol = 0;}
        if (Enable_Weekly)  {nIdx = nIdxWeekly;  nSumWeeklyTPV = 0;  nSumWeeklyVol = 0;}
        if (Enable_Monthly) {nIdx = nIdxMonthly; nSumMonthlyTPV = 0; nSumMonthlyVol = 0;}
        if (Enable_Yearly)  {nIdx = nIdxYearly;  nSumYearlyTPV = 0;  nSumYearlyVol = 0;}

        for(; nIdx < rates_total; nIdx++) {
            VWAP_Buffer_Daily[nIdx] = EMPTY_VALUE;
            VWAP_Buffer_Weekly[nIdx] = EMPTY_VALUE;
            VWAP_Buffer_Monthly[nIdx] = EMPTY_VALUE;
            VWAP_Buffer_Yearly[nIdx] = EMPTY_VALUE;

            if(CreateDateTime(DAILY, time[nIdx]) != dtLastDay) {
                nIdxDaily = nIdx;
                nSumDailyTPV = 0;
                nSumDailyVol = 0;
            }
            if(CreateDateTime(WEEKLY, time[nIdx]) != dtLastWeek) {
                nIdxWeekly = nIdx;
                nSumWeeklyTPV = 0;
                nSumWeeklyVol = 0;
            }
            if(CreateDateTime(MONTHLY, time[nIdx]) != dtLastMonth) {
                nIdxMonthly = nIdx;
                nSumMonthlyTPV = 0;
                nSumMonthlyVol = 0;
            }
            if(CreateDateTime(YEARLY, time[nIdx]) != dtLastYear) {
                nIdxYearly = nIdx;
                nSumYearlyTPV = 0;
                nSumYearlyVol = 0;
            }

            nPriceArr[nIdx] = 0;
            nTotalTPV[nIdx] = 0;
            nTotalVol[nIdx] = 0;

            switch(Price_Type) {
                case OPEN:
                    nPriceArr[nIdx] = open[nIdx];
                    break;
                case CLOSE:
                    nPriceArr[nIdx] = close[nIdx];
                    break;
                case HIGH:
                    nPriceArr[nIdx] = high[nIdx];
                    break;
                case LOW:
                    nPriceArr[nIdx] = low[nIdx];
                    break;
                case HIGH_LOW:
                    nPriceArr[nIdx] = (high[nIdx]+low[nIdx])/2;
                    break;
                case OPEN_CLOSE:
                    nPriceArr[nIdx] = (open[nIdx]+close[nIdx])/2;
                    break;
                case CLOSE_HIGH_LOW:
                    nPriceArr[nIdx] = (close[nIdx]+high[nIdx]+low[nIdx])/3;
                    break;
                case OPEN_CLOSE_HIGH_LOW:
                    nPriceArr[nIdx] = (open[nIdx]+close[nIdx]+high[nIdx]+low[nIdx])/4;
                    break;
                default:
                    nPriceArr[nIdx] = (close[nIdx]+high[nIdx]+low[nIdx])/3;
                    break;
            }

            if (tick_volume[nIdx]) {
                nTotalTPV[nIdx] = (nPriceArr[nIdx] * tick_volume[nIdx]);
                nTotalVol[nIdx] = (double)tick_volume[nIdx];
            } else if (volume[nIdx]) {
                nTotalTPV[nIdx] = (nPriceArr[nIdx] * volume[nIdx]);
                nTotalVol[nIdx] = (double)volume[nIdx];
            }

            if (Enable_Daily && (nIdx >= nIdxDaily)) {
                nSumDailyTPV += nTotalTPV[nIdx];
                nSumDailyVol += nTotalVol[nIdx];

                if (nSumDailyVol)
                    VWAP_Buffer_Daily[nIdx] = (nSumDailyTPV/nSumDailyVol);

                if((sDailyStr != "VWAP Daily: " + (string)NormalizeDouble(VWAP_Buffer_Daily[nIdx], _Digits)) && Show_Daily_Value) {
                    sDailyStr = "VWAP Daily: " + (string)NormalizeDouble(VWAP_Buffer_Daily[nIdx], _Digits);
                    ObjectSetString(0, "VWAP_Daily", OBJPROP_TEXT, sDailyStr);
                }
            }

            if (Enable_Weekly && (nIdx >= nIdxWeekly)) {
                nSumWeeklyTPV += nTotalTPV[nIdx];
                nSumWeeklyVol += nTotalVol[nIdx];

                if (nSumWeeklyVol)
                    VWAP_Buffer_Weekly[nIdx] = (nSumWeeklyTPV/nSumWeeklyVol);

                if((sWeeklyStr != "VWAP Weekly: " + (string)NormalizeDouble(VWAP_Buffer_Weekly[nIdx], _Digits)) && Show_Weekly_Value) {
                    sWeeklyStr = "VWAP Weekly: " + (string)NormalizeDouble(VWAP_Buffer_Weekly[nIdx], _Digits);
                    ObjectSetString(0, "VWAP_Weekly", OBJPROP_TEXT, sWeeklyStr);
                }
            }

            if (Enable_Monthly && (nIdx >= nIdxMonthly)) {
                nSumMonthlyTPV += nTotalTPV[nIdx];
                nSumMonthlyVol += nTotalVol[nIdx];

                if (nSumMonthlyVol)
                    VWAP_Buffer_Monthly[nIdx] = (nSumMonthlyTPV/nSumMonthlyVol);

                if((sMonthlyStr != "VWAP Monthly: " + (string)NormalizeDouble(VWAP_Buffer_Monthly[nIdx], _Digits)) && Show_Monthly_Value) {
                    sMonthlyStr = "VWAP Monthly: " + (string)NormalizeDouble(VWAP_Buffer_Monthly[nIdx], _Digits);
                    ObjectSetString(0, "VWAP_Monthly", OBJPROP_TEXT, sMonthlyStr);
                }
            }

            if (Enable_Yearly && (nIdx >= nIdxYearly)) {
                nSumYearlyTPV += nTotalTPV[nIdx];
                nSumYearlyVol += nTotalVol[nIdx];

                if (nSumYearlyVol)
                    VWAP_Buffer_Yearly[nIdx] = (nSumYearlyTPV/nSumYearlyVol);

                if((sYearlyStr != "VWAP Yearly: " + (string)NormalizeDouble(VWAP_Buffer_Yearly[nIdx], _Digits)) && Show_Yearly_Value) {
                    sYearlyStr = "VWAP Yearly: " + (string)NormalizeDouble(VWAP_Buffer_Yearly[nIdx], _Digits);
                    ObjectSetString(0, "VWAP_Yearly", OBJPROP_TEXT, sYearlyStr);
                }
            }

            dtLastDay = CreateDateTime(DAILY, time[nIdx]);
            dtLastWeek = CreateDateTime(WEEKLY, time[nIdx]);
            dtLastMonth = CreateDateTime(MONTHLY, time[nIdx]);
            dtLastYear = CreateDateTime(YEARLY, time[nIdx]);
        }

        bIsFirstRun = false;
    }

    // VWAP crossover alert detection
    if (Enable_Alert && rates_total > 0) {
        int currentBar = rates_total - 1;  // Current candlestick index
        
        // Detect VWAP alerts for each period
        if (Alert_On_Daily && Enable_Daily) {
            CheckVWAPAlert(currentBar, VWAP_Buffer_Daily, bAlertDaily, "Daily", open, high, low, close);
        }
        
        if (Alert_On_Weekly && Enable_Weekly) {
            CheckVWAPAlert(currentBar, VWAP_Buffer_Weekly, bAlertWeekly, "Weekly", open, high, low, close);
        }
        
        if (Alert_On_Monthly && Enable_Monthly) {
            CheckVWAPAlert(currentBar, VWAP_Buffer_Monthly, bAlertMonthly, "Monthly", open, high, low, close);
        }
        
        if (Alert_On_Yearly && Enable_Yearly) {
            CheckVWAPAlert(currentBar, VWAP_Buffer_Yearly, bAlertYearly, "Yearly", open, high, low, close);
        }
        
        // Detect new candlestick start, reset alert status
        if (prev_calculated > 0 && rates_total > prev_calculated) {
            bAlertDaily = false;
            bAlertWeekly = false;
            bAlertMonthly = false;
            bAlertYearly = false;
        }
    }

// Calculate and display candlestick closing countdown
if (Show_Countdown && rates_total > 0) {
        // Get current time
        datetime currentTime = TimeCurrent();
        
        // Get current candlestick start time
        datetime currentBarStart = time[rates_total - 1];
        
        // Calculate current candlestick end time (next candlestick start time)
        datetime nextBarStart = currentBarStart + PeriodSeconds(PERIOD_CURRENT);
        
        // Calculate remaining time (seconds)
        int remainingSeconds = (int)(nextBarStart - currentTime);
        
        // Ensure remaining time is not negative
        if (remainingSeconds < 0) remainingSeconds = 0;
        
        // Format countdown display
        int minutes = remainingSeconds / 60;
        int seconds = remainingSeconds % 60;
        
        string newCountdownStr = StringFormat("Candlestick Closing Countdown: %02d:%02d", minutes, seconds);
        
        // Only update display when countdown text changes
        if (sCountdownStr != newCountdownStr) {
            sCountdownStr = newCountdownStr;
            ObjectSetString(0, "KLine_Countdown", OBJPROP_TEXT, sCountdownStr);
        }
    }

    return(rates_total);
}