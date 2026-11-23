//+------------------------------------------------------------------+
//| Previous Day High Low.mq4                                         |
//| Draws the previous day's, week's and month's high, low and close. |
//| Free download and guide:                                           |
//| https://mt4indicators.com/mt4-indicator/previous-day-high-low-indicator-mt4/ |
//+------------------------------------------------------------------+
#property copyright   "mt4indicators.com"
#property link        "https://mt4indicators.com/mt4-indicator/previous-day-high-low-indicator-mt4/"
#property version     "1.00"
#property description "Previous day, week and month high, low and close as horizontal lines,"
#property description "built from the chart's own bars (no D1/W1/MN history needed)."
#property description "Optional alert when price touches a level. Uses broker server time."
#property strict
#property indicator_chart_window
#property indicator_buffers 0

input bool   ShowDay         = true;          // Show previous day levels
input bool   ShowWeek        = true;          // Show previous week levels
input bool   ShowMonth       = false;         // Show previous month levels
input bool   ShowClose       = false;         // Also draw the previous close
input int    DayStartHour    = 0;             // Day starts at this server hour (0-23)
input color  DayColor        = clrDodgerBlue; // Day line color
input color  WeekColor       = clrDarkOrange; // Week line color
input color  MonthColor      = clrMediumOrchid; // Month line color
input ENUM_LINE_STYLE LineStyle = STYLE_DASH; // Line style
input int    LineWidth       = 1;             // Line width
input bool   ShowLabels      = true;          // Show text labels
input bool   AlertOnTouch    = false;         // Alert when price touches a level
input bool   PushOnTouch     = false;         // Push notification on touch

string PFX = "PDHL_";
double lvl[9]; string lname[9]; datetime lastAlert[9];

int OnInit()
{
   IndicatorShortName("Previous Day High Low");
   ArrayInitialize(lastAlert,0);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason) { ObjectsDeleteAll(0, PFX); }

// Key of the period a bar belongs to: 0 = day, 1 = week, 2 = month
long PeriodKey(datetime t, int kind)
{
   datetime s = t - DayStartHour * 3600;
   if(kind == 0) return (long)(s / 86400);
   if(kind == 1) return (long)((s / 86400 + 3) / 7);           // weeks start Monday
   return (long)TimeYear(s) * 12 + TimeMonth(s);
}

// Previous completed period's high/low/close from chart bars
bool PrevHLC(int kind, const datetime &time[], const double &high[], const double &low[], const double &close[], int total, double &h, double &l, double &c, datetime &startT)
{
   long cur = PeriodKey(time[0], kind);
   int i = 0;
   while(i < total && PeriodKey(time[i], kind) == cur) i++;
   if(i >= total) return false;
   long prev = PeriodKey(time[i], kind);
   h = high[i]; l = low[i]; c = close[i];
   int j = i;
   while(j < total && PeriodKey(time[j], kind) == prev) { h = MathMax(h, high[j]); l = MathMin(l, low[j]); startT = time[j]; j++; }
   if(j >= total) return false;                                    // period not complete in history
   return true;
}

void DrawLevel(int k, string text, double price, datetime from, color clr)
{
   string n = PFX + IntegerToString(k);
   if(ObjectFind(0, n) < 0) ObjectCreate(0, n, OBJ_TREND, 0, from, price, Time[0], price);
   ObjectSetInteger(0, n, OBJPROP_TIME1, from);  ObjectSetDouble(0, n, OBJPROP_PRICE1, price);
   ObjectSetInteger(0, n, OBJPROP_TIME2, Time[0]); ObjectSetDouble(0, n, OBJPROP_PRICE2, price);
   ObjectSetInteger(0, n, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, n, OBJPROP_STYLE, LineStyle);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, LineWidth);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_BACK, true);
   ObjectSetString(0, n, OBJPROP_TOOLTIP, text + " " + DoubleToString(price, Digits));
   string t = n + "_t";
   if(!ShowLabels) { ObjectDelete(0, t); return; }
   if(ObjectFind(0, t) < 0) ObjectCreate(0, t, OBJ_TEXT, 0, Time[0], price);
   ObjectSetInteger(0, t, OBJPROP_TIME1, Time[0] + PeriodSeconds() * 3);
   ObjectSetDouble(0, t, OBJPROP_PRICE1, price);
   ObjectSetString(0, t, OBJPROP_TEXT, text + " " + DoubleToString(price, Digits));
   ObjectSetInteger(0, t, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, t, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, t, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, t, OBJPROP_SELECTABLE, false);
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[], const double &open[],
                const double &high[], const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   if(Period() > PERIOD_D1) return rates_total;
   ArraySetAsSeries(time, true); ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);
   string tag[3] = {"PD", "PW", "PM"}; bool on[3]; on[0] = ShowDay; on[1] = ShowWeek; on[2] = ShowMonth;
   color clr[3]; clr[0] = DayColor; clr[1] = WeekColor; clr[2] = MonthColor;
   for(int k = 0; k < 3; k++)
   {
      double h, l, c; datetime st = 0;
      bool ok = on[k] && PrevHLC(k, time, high, low, close, rates_total, h, l, c, st);
      for(int m = 0; m < 3; m++) lvl[k * 3 + m] = 0;
      if(!ok) { for(int m = 0; m < 3; m++) { ObjectDelete(0, PFX + IntegerToString(k * 3 + m)); ObjectDelete(0, PFX + IntegerToString(k * 3 + m) + "_t"); } continue; }
      DrawLevel(k * 3,     tag[k] + "H", h, st, clr[k]); lvl[k * 3] = h;     lname[k * 3] = tag[k] + "H";
      DrawLevel(k * 3 + 1, tag[k] + "L", l, st, clr[k]); lvl[k * 3 + 1] = l; lname[k * 3 + 1] = tag[k] + "L";
      if(ShowClose) { DrawLevel(k * 3 + 2, tag[k] + "C", c, st, clr[k]); lvl[k * 3 + 2] = c; lname[k * 3 + 2] = tag[k] + "C"; }
      else { ObjectDelete(0, PFX + IntegerToString(k * 3 + 2)); ObjectDelete(0, PFX + IntegerToString(k * 3 + 2) + "_t"); }
   }
   if((AlertOnTouch || PushOnTouch) && prev_calculated > 0)
      for(int k = 0; k < 9; k++)
      {
         if(lvl[k] <= 0 || lastAlert[k] == time[0]) continue;
         if(high[0] >= lvl[k] && low[0] <= lvl[k])
         {
            lastAlert[k] = time[0];
            string msg = Symbol() + " " + lname[k] + " touched at " + DoubleToString(lvl[k], Digits);
            if(AlertOnTouch) Alert(msg);
            if(PushOnTouch) SendNotification(msg);
         }
      }
   return rates_total;
}
