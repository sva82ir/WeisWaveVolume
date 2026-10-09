//+------------------------------------------------------------------+
//| WeisWaveVolume.mq5                                               |
//| Copyright 2026, Siavash Dev                                      |
//| https://www.rahkarenovin.ir                                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026 | Siavash Ahi | @Siavash.Trader | +98-937-162-5332"
#property link      "https://rahkarenovin.ir"
#property version   "1.00"
#property strict
#property description "این نرم افزار توسط مهندس سیاوش آهی طراحی و برنامه نویس شده است"
#property description "این نرم افزار دارای کپی رایت است، استفاده و کپی بدون اجازه آن پیگرد قانونی دارد"
#property description "+98-937-162-5332 | Telegram, WhatsApp, Bale"
#property description "RahkareNovin.ir"
#property description "Aparat.com/Siavash.Trader"
#property description "Youtube.com/@Siavash.Trader"
#property description "Instagram.com/Siavash.Trader"

#property indicator_separate_window
#property indicator_buffers 6
#property indicator_plots   2

#property indicator_label1  "WWV Up"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrLimeGreen
#property indicator_width1  3

#property indicator_label2  "WWV Down"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrTomato
#property indicator_width2  3

input int  InpTrendDetectionLength = 2;
const bool InpShowDistributionBelowZero = false;

double g_upBuffer[];
double g_downBuffer[];
double g_moveBuffer[];
double g_trendBuffer[];
double g_waveBuffer[];
double g_volumeBuffer[];

bool IsRising(const double &close_prices[], const int rates_total, const int index, const int length)
  {
   if(length <= 0)
      return false;

   if(index + length >= rates_total)
      return false;

   for(int step = 0; step < length; step++)
     {
      if(close_prices[index + step] <= close_prices[index + step + 1])
         return false;
     }

   return true;
  }

bool IsFalling(const double &close_prices[], const int rates_total, const int index, const int length)
  {
   if(length <= 0)
      return false;

   if(index + length >= rates_total)
      return false;

   for(int step = 0; step < length; step++)
     {
      if(close_prices[index + step] >= close_prices[index + step + 1])
         return false;
     }

   return true;
  }

int OnInit()
  {
   SetIndexBuffer(0, g_upBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, g_downBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, g_moveBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, g_trendBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, g_waveBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, g_volumeBuffer, INDICATOR_CALCULATIONS);

   ArraySetAsSeries(g_upBuffer, true);
   ArraySetAsSeries(g_downBuffer, true);
   ArraySetAsSeries(g_moveBuffer, true);
   ArraySetAsSeries(g_trendBuffer, true);
   ArraySetAsSeries(g_waveBuffer, true);
   ArraySetAsSeries(g_volumeBuffer, true);

   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_HISTOGRAM);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 3);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrLimeGreen);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_HISTOGRAM);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 3);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrTomato);

   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   IndicatorSetInteger(INDICATOR_LEVELS, 1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("WWV_LB %d", MathMax(1, InpTrendDetectionLength)));

   return INIT_SUCCEEDED;
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < 2)
      return 0;

   ArraySetAsSeries(close, true);
   ArraySetAsSeries(volume, true);
   ArraySetAsSeries(tick_volume, true);

   const int trend_length = MathMax(1, InpTrendDetectionLength);
   bool use_real_volume = false;
   const int volume_scan_bars = MathMin(rates_total, 100);
   for(int scan = 0; scan < volume_scan_bars; scan++)
     {
      if(volume[scan] > 0)
        {
         use_real_volume = true;
         break;
        }
     }

   g_moveBuffer[rates_total - 1] = 0.0;
   g_trendBuffer[rates_total - 1] = 0.0;
   g_waveBuffer[rates_total - 1] = 0.0;
   g_volumeBuffer[rates_total - 1] = (use_real_volume ? (double)volume[rates_total - 1] : (double)tick_volume[rates_total - 1]);
   g_upBuffer[rates_total - 1] = 0.0;
   g_downBuffer[rates_total - 1] = g_volumeBuffer[rates_total - 1];

   // Recalculate the full series to keep the recursive wave volume state consistent.
   for(int bar = rates_total - 2; bar >= 0; bar--)
     {
      const int previous_bar = bar + 1;
      const double source_volume = (use_real_volume ? (double)volume[bar] : (double)tick_volume[bar]);

      if(close[bar] > close[previous_bar])
         g_moveBuffer[bar] = 1.0;
      else if(close[bar] < close[previous_bar])
         g_moveBuffer[bar] = -1.0;
      else
         g_moveBuffer[bar] = 0.0;

      const double previous_move = g_moveBuffer[previous_bar];
      const double previous_trend = g_trendBuffer[previous_bar];
      if(g_moveBuffer[bar] != 0.0 && g_moveBuffer[bar] != previous_move)
         g_trendBuffer[bar] = g_moveBuffer[bar];
      else
         g_trendBuffer[bar] = previous_trend;

      const bool is_trending = (IsRising(close, rates_total, bar, trend_length) ||
                                IsFalling(close, rates_total, bar, trend_length));
      const double previous_wave = g_waveBuffer[previous_bar];
      if(g_trendBuffer[bar] != previous_wave && is_trending)
         g_waveBuffer[bar] = g_trendBuffer[bar];
      else
         g_waveBuffer[bar] = previous_wave;

      if(g_waveBuffer[bar] == previous_wave)
         g_volumeBuffer[bar] = g_volumeBuffer[previous_bar] + source_volume;
      else
         g_volumeBuffer[bar] = source_volume;

      if(g_waveBuffer[bar] == 1.0)
        {
         g_upBuffer[bar] = g_volumeBuffer[bar];
         g_downBuffer[bar] = 0.0;
        }
      else if(g_waveBuffer[bar] == -1.0)
        {
         g_upBuffer[bar] = 0.0;
         g_downBuffer[bar] = (InpShowDistributionBelowZero ? -g_volumeBuffer[bar] : g_volumeBuffer[bar]);
        }
      else
        {
         g_upBuffer[bar] = 0.0;
         g_downBuffer[bar] = 0.0;
        }
     }

   return rates_total;
  }
