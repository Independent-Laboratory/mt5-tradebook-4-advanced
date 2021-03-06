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
   SIGNAL_BUY,        // 買いシグナル
   SIGNAL_SELL,       // 売りシグナル
   SIGNAL_STAY,       // 保留シグナル
};

#define MAX_BAR_NUM 50  // 売買シグナル判定処理に使うローソク足の本数

long magic = 101010;  // このプログラムのマジックナンバー

//--- パラメータ
input double   sl_point = 1000;  // 損切りポイント幅      
input double   tp_point = 3200;  // 利確ポイント幅         
input double   my_lot = 0.1;     // 売買するロット数
input int      slippage = 1;     // スリッページ
input int      max_position = 1; // 最大保有ポジション数

// スマホアプリへのメッセージ送信を有効化するか (true=有効/false=無効)
input bool     enable_send_message = true;  

input int      sma_period_short = 24;  // 短期SMAの期間        
input int      sma_period_middle = 36; // 中期SMAの期間
input int      sma_period_long = 48;   // 長期SMAの期間
input int      rsi_period = 14;        // RSIの期間


// テクニカル指標のハンドラ (エラー値で初期化している)
int handle_sma_short = INVALID_HANDLE;    // 短期SMAのハンドラを保存するための変数
int handle_sma_middle = INVALID_HANDLE;   // 中期SMAのハンドラを保存するための変数
int handle_sma_long = INVALID_HANDLE;     // 長期SMAのハンドラを保存するための変数
int handle_rsi = INVALID_HANDLE;          // RSIのハンドラを保存するための変数

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // テクニカル指標のグラフを右にずらす場合は、ずらす数を指定する
   int shift = 0;
   // RSIハンドラの作成
   handle_rsi = iRSI(Symbol(), PERIOD_CURRENT, rsi_period, PRICE_CLOSE);
   // 短期SMAのハンドラの作成
   handle_sma_short 
      = iMA(Symbol(), PERIOD_CURRENT, sma_period_short, shift, MODE_SMA, PRICE_CLOSE);
   // 中期SMAのハンドラの作成
   handle_sma_middle 
      = iMA(Symbol(), PERIOD_CURRENT, sma_period_middle, shift, MODE_SMA, PRICE_CLOSE);
   // 長期SMAのハンドラの作成
   handle_sma_long 
      = iMA(Symbol(), PERIOD_CURRENT, sma_period_long, shift, MODE_SMA, PRICE_CLOSE);
   
   if (handle_rsi == INVALID_HANDLE) {
      PrintFormat("Error: RSIハンドラの作成に失敗しました "
                  + "(通貨ペア: %s, 時間足: %s, エラーコード: %d)",
                   Symbol(), EnumToString(PERIOD_CURRENT), GetLastError());
      return(INIT_FAILED);
   }
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
   
   // スマホアプリにメッセージを送る (本番トレードの場合のみ有効)
   send_message(enable_send_message, "Init OK");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // 作ったハンドラはプログラム停止直前に明示的に削除するのが作法
   // ハンドラの中身が初期状態 (INVALID_HANDLE) でない場合は処理を進める
   // RSIハンドラの削除
   if (handle_rsi != INVALID_HANDLE) {
      IndicatorRelease(handle_rsi);
   }
   
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
}
  
//+------------------------------------------------------------------+
//| 売買シグナル判定                                                 |
//+------------------------------------------------------------------+
my_signal check_signal(bool for_opened_position, int position_type) {   
   my_signal signal = SIGNAL_STAY;      // シグナルを保留シグナルとしておく
                 
   datetime time[MAX_BAR_NUM] = {0};  // ローソク足の時刻を保存するための配列
   double open[MAX_BAR_NUM] = {0};    // ローソク足の始値を保存するための配列
   double close[MAX_BAR_NUM] = {0};   // ローソク足の終値を保存するための配列
   double high[MAX_BAR_NUM] = {0};    // ローソク足の高値を保存するための配列
   double low[MAX_BAR_NUM] = {0};     // ローソク足の安値を保存するための配列
   double rsi[MAX_BAR_NUM] = {0};     // RSIの値を保存するための配列
   double sma_short[MAX_BAR_NUM] = {0};  // 短期SMAの値を保存するための配列
   double sma_middle[MAX_BAR_NUM] = {0}; // 中期SMAの値を保存するための配列
   double sma_long[MAX_BAR_NUM] = {0};   // 長期SMAの値を保存するための配列

   // ローソク足の情報をMAX_BAR_NUM本分取得する
   // 最新順に取得し、配列の末尾から先頭に向かって値を詰めていく
   for(int i = 0; i < MAX_BAR_NUM; i++) {
      time[MAX_BAR_NUM - 1 - i]  = iTime(Symbol(), Period(), i);
      open[MAX_BAR_NUM - 1 - i]  = iOpen(Symbol(), Period(), i);
      high[MAX_BAR_NUM - 1 - i]  = iHigh(Symbol(), Period(), i);
      low[MAX_BAR_NUM - 1 - i]   = iLow(Symbol(), Period(), i);
      close[MAX_BAR_NUM - 1 - i] = iClose(Symbol(), Period(), i);
   }
   
   // テクニカルチャートの値が保存されているバッファのID。通常は0を指定する。
   int buf_id = 0;
   // 値を取得し始める位置。0が最新の時刻のデータを意味する。
   int start_pos = 0;

   // RSIの値を取得
   if (CopyBuffer(handle_rsi, buf_id, start_pos, MAX_BAR_NUM, rsi) != MAX_BAR_NUM) {
      Print("Error: RSIの値の取得に失敗しました");
   }
   
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
   
   // テクニカル指標のうち、売買シグナルの生成に使用する最新の値のみを取り出す
   // (わかりやすさのため)
   // 配列の末尾の値は確定していないローソク足から算出した値であるため、
   // 配列の末尾から2番目の値を取得する
   double rsi_latest = rsi[MAX_BAR_NUM - 2];
   double sma_short_latest = sma_short[MAX_BAR_NUM - 2];
   double sma_middle_latest = sma_middle[MAX_BAR_NUM - 2];
   double sma_long_latest = sma_long[MAX_BAR_NUM - 2];
   datetime time_latest = time[MAX_BAR_NUM - 2];
   
   // --- 各種トレード条件の作成 ---
   // 上昇トレンドのパーフェクトオーダーが検出された場合はtrue、
   // 検出されなかった場合はfalseになる
   bool perfect_order_up 
      = ((sma_long_latest < sma_middle_latest) && (sma_middle_latest < sma_short_latest));
   
   // 下降トレンドのパーフェクトオーダーが検出された場合はtrue、
   //  検出されなかった場合はfalseになる
   bool perfect_order_down 
      = ((sma_short_latest < sma_middle_latest) && (sma_middle_latest < sma_long_latest));
   
   // RSIが90から100のとき (買われすぎのとき) はTrue、それ以外のときにはfalseになる
   bool rsi_too_bought = ((90 <= rsi_latest) && (rsi_latest <= 100));
   
   // RSIが0から10のとき (売られすぎのとき) はTrue、それ以外のときにはfalseになる
   bool rsi_too_sold = ((0 <= rsi_latest) && (rsi_latest <= 10));
   
   // ポジションが決済されていない場合
   if (for_opened_position) {
      // 買いポジションの場合は、上昇トレンドのパーフェクトオーダーが検出されなくなった、
      // またはRSIが買われすぎを示した時点で決済シグナルを出す。
      if ((position_type == POSITION_TYPE_BUY) && (!perfect_order_up || rsi_too_bought)) {
         signal = SIGNAL_CLOSE;
      }
      
      // 売りポジションの場合は、下降トレンドのパーフェクトオーダーが検出されなくなった、
      // またはRSIが売られすぎを検出した時点で決済シグナルを出す。
      if ((position_type == POSITION_TYPE_SELL) && (!perfect_order_down || rsi_too_sold)) {
         signal = SIGNAL_CLOSE;
      }
   }
   // 未注文の場合
   else {      
      // 上昇トレンドのパーフェクトオーダーが検出されていて、
      // RSIが買われすぎを示していないときは売り注文を出す
      if (perfect_order_up && !rsi_too_bought) {
         signal = SIGNAL_BUY;
      }
      
      // 下降トレンドのパーフェクトオーダーが検出されていて、
      // RSIが売られすぎを示していないときは買い注文を出す
      else if (perfect_order_down && !rsi_too_sold) {
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
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
   static int prev_bars = 0;  // 前回のローソク足の数を記憶するための変数

   // レートの更新毎に実行する
   int bars = Bars(Symbol(), PERIOD_CURRENT);  // 最新のローソク足の本数を取得

   // ローソク足の本数に変化がない場合は関数を終了する
   if (prev_bars == bars) {
      return;
   }
   // ローソク足の本数に変化があった場合は、
   // ローソク足の記録を更新して、これ以降の処理を続ける
   else {
      prev_bars = bars;
   }
   
   // ----- ローソク足が出現する度に実行される処理 (開始) -----
   
   // ========== 決済処理 =========
   // ポジション数を取得する
   int position_total = PositionsTotal();
   
   // 全ポジションを新着順に調べる
   int my_position_cnt = 0;  // マジックナンバーが一致したポジションの数
   for (int index = position_total - 1; index >= 0; index--) {
      // 注目しているポジションのチケット番号を取得する
      ulong ticket = PositionGetTicket(index);
      if (ticket == 0) {
         Print("Error: ポジションのチケット番号の取得に失敗しました (ポジション番号: "
               + string(index) + ")");
         return;
      }
      
      // 注目しているチケットが操作対象としてセットできれば、
      // マジックナンバーが一致していることになる
      // マジックナンバーが異なる場合は、
      // 他のプログラムが担当しているチケットであるため無視する
      if (!set_target_ticket_with_magic(ticket, magic)) {
         continue;
      }

      // このスクリプトの担当ポジションが見つかったため、合計数に加える
      my_position_cnt++;
      
      // ポジションが買いか売りかを確認する
      int type = (int)PositionGetInteger(POSITION_TYPE);  // ポジションタイプ
      
      // ポジションの買い状態/売り状態とチャートの状態を考慮して、
      // 決済するかどうかを判断する
      int signal = check_signal(true, type);
      // 決済シグナルが出ている場合は、決済する
      if (signal == SIGNAL_CLOSE) {
          order_close(ticket, slippage, magic);
          my_position_cnt--;  // ポジションをクローズしたため、合計数を1つ減らす
      }
   }
   
   // 保有ポジション数が
   // このプログラムの最大担当ポジション数を満たしていれば処理を終える
   if (my_position_cnt >= max_position) {
      return;
   }
   
   // ========== 新規売買 =========
   // 保有ポジション数がこのプログラムの最大担当ポジション数を満たしていない場合は、
   // ローソク足1つ増えるごとに1つポジションを増やすことを検討する      
   double sl;  // ストップロスを置くレートを保存するための変数
   double tp;  // テイクプロフィットを置くレートを保存するための変数
   
   // 買い/売りシグナルが出ているかどうかを確認する
   int signal = check_signal(false, 0);
   
   // --- シグナルに従って売買を行う ---
   // 買いシグナルが出ている場合  
   if (signal == SIGNAL_BUY) {
      // SL, TPの位置をポイント幅から計算し、変数sl, tpにそれぞれ保存する
      sl_tp_calc_from_point(ORDER_TYPE_BUY, sl_point, tp_point, sl, tp);
      // 買い注文を出す
      order_open(ORDER_TYPE_BUY, my_lot, slippage, sl, tp, magic);   
   }
   // 売りシグナルが出ている場合  
   else if (signal == SIGNAL_SELL) {
      // SL, TPの位置をポイント幅から計算し、変数sl, tpにそれぞれ保存する
      sl_tp_calc_from_point(ORDER_TYPE_SELL, sl_point, tp_point, sl, tp);
      // 売り注文を出す
      order_open(ORDER_TYPE_SELL, my_lot, slippage, sl, tp, magic);
   }
   
   // ----- ローソク足が出現する度に実行される処理 (終了) -----
}
//+------------------------------------------------------------------+
