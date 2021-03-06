//+------------------------------------------------------------------+
//|                           Copyright 2021, Independent Laboratory |
//|                                   https://www.independentlab.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Independent Laboratory"
#property link     "https://www.independentlab.net"
#property version   "1.00"

#include <my_library.mqh>

//--- 定数定義

// 売買シグナルの定数
enum my_signal {
   SIGNAL_CLOSE = 1,  // 決済シグナル
   SIGNAL_BUY,      // 買いシグナル
   SIGNAL_SELL,      // 売りシグナル
   SIGNAL_STAY,      // 保留シグナル
};

#define MAX_BAR_NUM 50  // 売買シグナル判定処理に使うローソク足の本数
#define BO_BAR_NUM 3  // バイナリーオプションの勝率計算に使用するローソク足の本数

long magic = 201010;  // このプログラムのマジックナンバー

//--- 固定の設定値       
double   my_lot = 0.01; // 売買するロット数
int      slippage = 1;  // スリッページ

//--- パラメータ
input int      sma_period_short = 24;  // 短期SMAの期間        
input int      sma_period_middle = 36; // 中期SMAの期間
input int      sma_period_long = 48;   // 長期SMAの期間
input int      rsi_period = 5;         // RSIの期間
input int      cci_period = 5;         // CCIの期間
input int      adx_period = 5;         // ADXの期間
input double   spread = 0.004;         // 想定スプレッド


// テクニカル指標のハンドラ (エラー値で初期化している)
int handle_sma_short = INVALID_HANDLE;  // 短期SMAのハンドラを保存するための変数
int handle_sma_middle = INVALID_HANDLE; // 中期SMAのハンドラを保存するための変数
int handle_sma_long = INVALID_HANDLE;   // 長期SMAのハンドラを保存するための変数
int handle_rsi = INVALID_HANDLE;  // RSIのハンドラを保存するための変数
int handle_cci = INVALID_HANDLE;  // CCIのハンドラを保存するための変数
int handle_adx = INVALID_HANDLE;  // ADXのハンドラを保存するための変数

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   int shift = 0;  // テクニカル指標を右にずらす場合は、ずらす数を指定する
   // 短期SMAのハンドラの作成
   handle_sma_short 
     = iMA(Symbol(), PERIOD_CURRENT, sma_period_short, shift, MODE_SMA, PRICE_CLOSE);
   // 中期SMAのハンドラの作成
   handle_sma_middle 
     = iMA(Symbol(), PERIOD_CURRENT, sma_period_middle, shift, MODE_SMA, PRICE_CLOSE);
   // 長期SMAのハンドラの作成
   handle_sma_long 
     = iMA(Symbol(), PERIOD_CURRENT, sma_period_long, shift, MODE_SMA, PRICE_CLOSE);
   // RSIハンドラの作成
   handle_rsi = iRSI(Symbol(), PERIOD_CURRENT, rsi_period, PRICE_CLOSE);
   // CCIハンドラの作成
   handle_cci = iCCI(Symbol(), PERIOD_CURRENT, cci_period, PRICE_CLOSE);
   // ADXハンドラの作成
   handle_adx = iADXWilder(Symbol(), PERIOD_CURRENT, adx_period);

   if (handle_sma_short == INVALID_HANDLE) {
      PrintFormat("Error: 短期SMAのハンドラの作成に失敗しました "
                  + "(通貨ペア: %s, 時間足: %s, エラーコード: %d)",
                  Symbol(), EnumToString(PERIOD_CURRENT), GetLastError());
      return(INIT_FAILED);
   }
   if (handle_sma_middle == INVALID_HANDLE) {
      PrintFormat("Error: 中期SMAのハンドラの作成に失敗しました "
                  + "(通貨ペア: %s, 時間足: %s, エラーコード: %d)",
                  Symbol(), EnumToString(PERIOD_CURRENT), GetLastError());
      return(INIT_FAILED);
   }
   if (handle_sma_long == INVALID_HANDLE) {
      PrintFormat("Error: 長期SMAのハンドラの作成に失敗しました "
                  + "(通貨ペア: %s, 時間足: %s, エラーコード: %d)",
                  Symbol(), EnumToString(PERIOD_CURRENT), GetLastError());
      return(INIT_FAILED);
   }
   if (handle_rsi == INVALID_HANDLE) {
      PrintFormat("Error: RSIハンドラの作成に失敗しました "
                  + "(通貨ペア: %s, 時間足: %s, エラーコード: %d)",
                  Symbol(), EnumToString(PERIOD_CURRENT), GetLastError());
      return(INIT_FAILED);
   }
   if (handle_cci == INVALID_HANDLE) {
      PrintFormat("Error: CCIハンドラの作成に失敗しました "
                  + "(通貨ペア: %s, 時間足: %s, エラーコード: %d)",
                  Symbol(), EnumToString(PERIOD_CURRENT), GetLastError());
      return(INIT_FAILED);
   }
   if (handle_adx == INVALID_HANDLE) {
      PrintFormat("Error: ADXハンドラの作成に失敗しました "
                  + "(通貨ペア: %s, 時間足: %s, エラーコード: %d)",
                  Symbol(), EnumToString(PERIOD_CURRENT), GetLastError());
      return(INIT_FAILED);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // 作ったハンドラはプログラム停止直前に明示的に削除することが作法
   // ハンドラの中身が初期状態 (INVALID_HANDLE) でない場合は処理を進める
   
   // 短期SMAハンドラの削除
   if (handle_sma_short != INVALID_HANDLE) {
      IndicatorRelease(handle_sma_short);
   }
   
   // 中期SMAハンドラの削除
   if (handle_sma_middle != INVALID_HANDLE) {
      IndicatorRelease(handle_sma_middle); 
   }
   
   // 長期SMAハンドラの削除
   if (handle_sma_long != INVALID_HANDLE) {
      IndicatorRelease(handle_sma_long);
   }
   
   // RSIハンドラの削除
   if (handle_rsi != INVALID_HANDLE) {
      IndicatorRelease(handle_rsi);
   }
   
   // CCIハンドラの削除
   if (handle_cci != INVALID_HANDLE) {
      IndicatorRelease(handle_cci);
   }
   
   // ADXハンドラの削除
   if (handle_adx != INVALID_HANDLE) {
      IndicatorRelease(handle_adx);
   }
}

//+------------------------------------------------------------------+
//| 売買シグナル判定                                                 |
//+------------------------------------------------------------------+
my_signal check_signal(bool for_opened_position, int position_type) {   
   my_signal signal = SIGNAL_STAY;       // シグナルを保留シグナルとしておく
                 
   datetime time[MAX_BAR_NUM] = {0};     // ローソク足の時刻を保存するための配列
   double open[MAX_BAR_NUM] = {0};       // ローソク足の始値を保存するための配列
   double close[MAX_BAR_NUM] = {0};      // ローソク足の終値を保存するための配列
   double high[MAX_BAR_NUM] = {0};       // ローソク足の高値を保存するための配列
   double low[MAX_BAR_NUM] = {0};        // ローソク足の安値を保存するための配列
   double sma_short[MAX_BAR_NUM] = {0};  // 短期SMAの値を保存するための配列
   double sma_middle[MAX_BAR_NUM] = {0}; // 中期SMAの値を保存するための配列
   double sma_long[MAX_BAR_NUM] = {0};   // 長期SMAの値を保存するための配列
   double rsi[MAX_BAR_NUM] = {0};        // RSIの値を保存するための配列
   double cci[MAX_BAR_NUM] = {0};        // CCIの値を保存するための配列
   double adx_main[MAX_BAR_NUM] = {0};   // ADXの値を保存するための配列
   double adx_plus_DI[MAX_BAR_NUM] = {0};  // ADXの+DIの値を保存するための配列
   double adx_minus_DI[MAX_BAR_NUM] = {0}; // ADXの-DIの値を保存するための配列

   // ローソク足の情報をMAX_BAR_NUM本分取得する
   // 最新順に取得し、配列の末尾から先頭に向かって値を詰めていく
   for(int i = 0; i < MAX_BAR_NUM; i++) {
      time[MAX_BAR_NUM - 1 - i]  = iTime(Symbol(),Period(), i);
      open[MAX_BAR_NUM - 1 - i]  = iOpen(Symbol(),Period(), i);
      high[MAX_BAR_NUM - 1 - i]  = iHigh(Symbol(),Period(), i);
      low[MAX_BAR_NUM - 1 - i]   = iLow(Symbol(),Period(), i);
      close[MAX_BAR_NUM - 1 - i] = iClose(Symbol(),Period(), i);
   }
  
   // テクニカルチャートの値が保存されているバッファのID。通常は0を指定する。 
   int buf_id = 0;
   
   int buf_id_plus_DI = 1;   // ADXの+DIの値が保存されるバッファのIDは1
   int buf_id_minus_DI = 2;  // ADXの-DIの値が保存されるバッファのIDは2
   
   int start_pos = 0;  // 値を取得し始める位置。0が最新の時刻のデータを意味する。
   
   // 短期SMAの値を取得
   if (CopyBuffer(handle_sma_short, buf_id, start_pos, MAX_BAR_NUM, sma_short) != MAX_BAR_NUM) {
      Print("Error: 短期SMAの値の取得に失敗しました");
   }
   
   // 中期SMAの値を取得
   if (CopyBuffer(handle_sma_middle, buf_id, start_pos, MAX_BAR_NUM, sma_middle) != MAX_BAR_NUM) {
      Print("Error: 中期SMAの値の取得に失敗しました");
   }
   
   // 長期SMAの値を取得
   if (CopyBuffer(handle_sma_long, buf_id, start_pos, MAX_BAR_NUM, sma_long) != MAX_BAR_NUM) {
      Print("Error: 長期SMA値の取得に失敗しました");
   }
   
   // RSIの値を取得
   if (CopyBuffer(handle_rsi, buf_id, start_pos, MAX_BAR_NUM, rsi) != MAX_BAR_NUM) {
      Print("Error: RSIの値の取得に失敗しました");
   }
   
   // CCIの値を取得
   if (CopyBuffer(handle_cci, buf_id, start_pos, MAX_BAR_NUM, cci) != MAX_BAR_NUM) {
      Print("Error: CCIの値の取得に失敗しました");
   }
   
   // ADX (メイン) の値の取得
   if (CopyBuffer(handle_adx, buf_id, start_pos, MAX_BAR_NUM, adx_main) != MAX_BAR_NUM) {
      Print("Error: ADX (メイン) の値の取得に失敗しました");
   }
   
   // ADX (+DI) の値の取得
   if (CopyBuffer(handle_adx, buf_id_plus_DI, start_pos, MAX_BAR_NUM, adx_plus_DI) != MAX_BAR_NUM) {
      Print("Error: ADX (+DI) の値の取得に失敗しました");
   }
   
   // ADX (-DI) の値の取得
   if (CopyBuffer(handle_adx, buf_id_minus_DI, start_pos, MAX_BAR_NUM, adx_minus_DI) != MAX_BAR_NUM) {
      Print("Error: ADX (-DI) の値の取得に失敗しました");
   }
   
   // テクニカル指標のうち、売買シグナルの生成に使用する最新の値のみを取り出す
   // (わかりやすさのため)
   // 配列の末尾の値は確定していないローソク足から算出した値であるため、
   // 配列の末尾から2番目の値を取得する
   datetime time_latest = time[MAX_BAR_NUM - 2];
   double sma_short_latest = sma_short[MAX_BAR_NUM - 2];
   double sma_middle_latest = sma_middle[MAX_BAR_NUM - 2];
   double sma_long_latest = sma_long[MAX_BAR_NUM - 2];
   double rsi_latest = rsi[MAX_BAR_NUM - 2];
   double cci_latest = cci[MAX_BAR_NUM - 2];
   double adx_main_latest = adx_main[MAX_BAR_NUM - 2];
   double adx_plus_DI_latest = adx_plus_DI[MAX_BAR_NUM - 2];
   double adx_minus_DI_latest = adx_minus_DI[MAX_BAR_NUM - 2];
   
   // 同様に最新のデータよりも1つ前のデータも取得しておく
   datetime time_prev_1 = time[MAX_BAR_NUM - 3];
   double sma_short_prev_1 = sma_short[MAX_BAR_NUM - 3];
   double sma_middle_prev_1 = sma_middle[MAX_BAR_NUM - 3];
   double sma_long_prev_1 = sma_long[MAX_BAR_NUM - 3];
   double rsi_prev_1 = rsi[MAX_BAR_NUM - 3];
   double cci_prev_1 = cci[MAX_BAR_NUM - 3];
   double adx_main_prev_1 = adx_main[MAX_BAR_NUM - 3];
   double adx_plus_DI_prev_1 = adx_plus_DI[MAX_BAR_NUM - 3];
   double adx_minus_DI_prev_1 = adx_minus_DI[MAX_BAR_NUM - 3];
   
   // datetime型の時刻をMqlDateTime型に変換することで、シグナル生成処理に使用しやすい形にする
   MqlDateTime latest_time_mql;
   TimeToStruct(time_latest, latest_time_mql);
   
   // MT5の時刻が日本の時刻を一致させる (境界で誤差あり)
   // ※単純に時間を足すだけでは24時時間を超えてしまう場合があるため、24時間で丸める
   // ・キプロス夏時間の場合: +6時間する
   //   (3月最終日曜日午前1時～10月最終日曜日午前1時) -> 大まかに4月から11月とする
   // ・キプロス冬時間の場合 (夏時間以外): +7時間する
   
   // キプロス冬時間→日本時間
   int jst_hour = (latest_time_mql.hour + 7) % 24;
   
   // キプロス夏時間→日本時間
   if ((4 <= latest_time_mql.mon) && (latest_time_mql.mon <= 10)) {
      jst_hour = (latest_time_mql.hour + 6) % 24; 
   }
   
   // --- 各種トレード条件の作成 ---
   // トレード禁止時間の指定
   bool no_trade_time = !((7 <= jst_hour) && (jst_hour < 17));

   // 上昇トレンドのパーフェクトオーダーが検出された場合はtrue、
   // 検出されなかった場合はfalseになる
   bool perfect_order_up 
      = ((sma_long_latest < sma_middle_latest) && (sma_middle_latest < sma_short_latest));
   
   // 下降トレンドのパーフェクトオーダーが検出された場合はtrue、
   // 検出されなかった場合はfalseになる
   bool perfect_order_down 
      = ((sma_short_latest < sma_middle_latest) && (sma_middle_latest < sma_long_latest));
   
   // RSIが90から100のとき (買われすぎのとき) はTrue、
   // それ以外のときにはfalseになる
   bool rsi_too_bought = ((90 <= rsi_latest) && (rsi_latest <= 100));
   
   // RSIが0から10のとき (売られすぎのとき) はTrue、
   // それ以外のときにはfalseになる
   bool rsi_too_sold = ((0 <= rsi_latest) && (rsi_latest <= 10));
   
   // CCIが130の値の線を上に抜けたとき (買われすぎのとき) はTrue, 
   // それ以外のときにはfalseになる
   bool cci_too_bought = ((cci_prev_1 < 130) && (130 < cci_latest));
   
   // CCIが-130の値の線を下に抜けたとき 売られすぎのとき) はTrue, 
   // それ以外のときにはfalseになる
   bool cci_too_sold = ((-130 < cci_prev_1) && (cci_latest < -130));
   
   // ADX (メイン) が30を上回るとき (上昇、または下降トレンドの発生時) はtrue, 
   // それ以外のときはfalseになる
   bool adx_main_trend = (30 < adx_main_latest);
   
   // ADX (+DI) が30を上回るとき (上昇トレンドの発生時) はtrue, 
   // それ以外のときはfalseになる
   bool adx_plus_DI_trend = (30 < adx_plus_DI_latest);
   
   // ADX (-DI) が30を上回るとき (下降トレンドの発生時) はtrue, 
   // それ以外のときはfalseになる
   bool adx_minus_DI_trend = (30 < adx_minus_DI_latest);
   
   // ポジションが決済されていない場合
   if (for_opened_position) {
      // バイナリーオプションでは、
      // 決済は一定時間後に自動的に行われるため、
      // 決済処理は行わない
   }
   // 未注文の場合
   else {
      if (rsi_too_sold) {
         signal = SIGNAL_BUY;
      }
      else if (rsi_too_bought) {
         signal = SIGNAL_SELL;
      }
      else {
         // 売買するべきではない
         signal = SIGNAL_STAY;
      }
   }
   
   return signal; // SIGNAL_STAY, SIGNAL_SELL, SIGNAL_BUY, SIGNAL_CLOSE
}

//+------------------------------------------------------------------+
//| バイナリーオプションの勝率計算                                   |
//+------------------------------------------------------------------+
void check_bo_winning_rate(my_signal previous_signal) {
   static int trade_num = 0;    // トレード回数
   static int winning_num = 0;  // 勝利回数
   
   // スプレッドを考慮した場合の勝利回数
   static int winning_num_with_spread = 0;
   
   // 新規トレードがない場合は何もしない
   if ((previous_signal != SIGNAL_BUY) && (previous_signal != SIGNAL_SELL)) {
      return;
   }
   
   // 新規トレードがあったため、トレード回数を1つ増やす
   trade_num += 1;
   
   // 確定した最新のローソク足を取得する
   datetime time[BO_BAR_NUM] = {0};    // ローソク足の時刻を保存するための配列
   double close[BO_BAR_NUM] = {0};     // ローソク足の終値を保存するための配列
   
   for(int i = 0; i < BO_BAR_NUM; i++) {
      time[BO_BAR_NUM - 1 - i]  = iTime(Symbol(),Period(), i);
      close[BO_BAR_NUM - 1 - i] = iClose(Symbol(),Period(), i);
   }
   
   datetime trade_time = time[BO_BAR_NUM - 2];      // トレードをした時刻
   double close_previous_2 = close[BO_BAR_NUM - 3];  // 2つ前に確定したローソク足の終値
   double close_previous_1 = close[BO_BAR_NUM - 2]; // 1つ前に確定したローソク足の終値
   
   Print("トレード時刻: " + string(trade_time));
   
   // 勝敗を判定する (スプレッド無しの場合)
   // 買い注文 (High) のとき、実際に終値が上昇していた場合は勝利
   if ((previous_signal == SIGNAL_BUY) && (close_previous_2 < close_previous_1)) {
      winning_num += 1;
      Print("Win (High)");
   }
   // 売り注文 (Low) のとき、実際に終値が下降していた場合は勝利
   else if ((previous_signal == SIGNAL_SELL) && (close_previous_1 < close_previous_2)) {
      winning_num += 1;
      Print("Win (Low)");
   }
   else {
      Print("Lose");
   }
   
   // 勝敗を判定する (スプレッドありの場合)
   // 買い注文 (High) のとき、実際に終値が上昇していた場合は勝利
   if ((previous_signal == SIGNAL_BUY) && (close_previous_2 + spread < close_previous_1)) {
      winning_num_with_spread += 1;
   }
   // 売り注文 (Low) のとき、実際に終値が下降していた場合は勝利
   else if ((previous_signal == SIGNAL_SELL) && (close_previous_1 < close_previous_2 - spread)) {
      winning_num_with_spread += 1;
   }
   
   // 勝率計算を行う
   double winning_rate = 0;  // スプレッドがない場合の勝率
   double winning_rate_with_spread = 0; // スプレッドがある場合の勝率
   
   if (trade_num > 0) {  // 0による割り算を念のため防ぐ
      winning_rate = (double)winning_num / (double)trade_num;
      winning_rate_with_spread = (double)winning_num_with_spread / (double)trade_num;
   }
   
   // 勝率を表示する
   PrintFormat("スプレッドなしの勝率: %f (回数: %d/%d)", 
               winning_rate, winning_num, trade_num);
               
   PrintFormat("スプレッドありの勝率: %f (回数: %d/%d)", 
               winning_rate_with_spread, winning_num_with_spread, trade_num);
   
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
   static int prev_bars = 0;  // 前回のローソク足の数を記憶するための変数
   
   // 前回の注文方向(買い=High/売り=Low)を記憶するための変数
   static my_signal previous_signal = SIGNAL_STAY;

   // レートの更新毎に実行する
   int bars = Bars(Symbol(), PERIOD_CURRENT);  // 最新のローソク足の本数を取得

   // ローソク足の本数に変化がない場合は関数を終了する
   if (prev_bars == bars) {
      return;
   }
   // ローソク足の本数に変化があった場合は、ローソク足の記録を更新して、
   // これ以降の処理を続ける
   else {
      prev_bars = bars;
   }
   
   // ----- ローソク足が出現する度に実行される処理 (開始) -----
   
   // ========== バイナリーオプションの勝率計算 =========
   check_bo_winning_rate(previous_signal);
   previous_signal = SIGNAL_STAY; // 前回のシグナルをリセットする
   
   // ========== 決済処理 =========
   // ポジション数を取得する
   int position_total = PositionsTotal();
   
   // 全ポジションを新着順に調べる
   for (int index = position_total - 1; index >= 0; index--) {
      // 注目しているポジションのチケット番号を取得する
      ulong ticket = PositionGetTicket(index);
      if (ticket == 0) {
         Print("Error: ポジションのチケット番号の取得に失敗しました "
               + "(ポジション番号: " + string(index) + ")");
         return;
      }
      
      // 注目しているチケットが操作対象としてセットできれば、
      // マジックナンバーが一致していることになる
      // マジックナンバーが異なる場合は、
      // 他のプログラムが担当しているチケットであるため無視する
      if (!set_target_ticket_with_magic(ticket, magic)) {
         continue;
      }
      
      // [バイナリーオプション過去検証特有の処理]
      // 1つ前のローソク足で作成したポジションを決済することで、
      // バイナリーオプションの売買位置をチャート上で可視化する
      order_close(ticket, slippage, magic);
   }
   
   // ========== 新規売買 =========     
   // 買い/売りシグナルが出ているかどうかを確認する
   my_signal signal = check_signal(false, 0);
   
   // --- シグナルに従って売買を行う ---
   // バイナリーオプションではストップロス、テイクプロフィットともに0
   double sl = 0;
   double tp = 0;
   
   // 買いシグナルが出ている場合  
   if (signal == SIGNAL_BUY) {
      // 買い注文を出す
      order_open(ORDER_TYPE_BUY, my_lot, slippage, sl, tp, magic);   
   }
   // 売りシグナルが出ている場合
   else if (signal == SIGNAL_SELL) {
      order_open(ORDER_TYPE_SELL, my_lot, slippage, sl, tp, magic);
   }
   
   // 今回のシグナルを記憶しておく
   previous_signal = signal;
   
   // ----- ローソク足が出現する度に実行される処理 (終了) -----
}
//+------------------------------------------------------------------+
