//+------------------------------------------------------------------+
//|                           Copyright 2021, Independent Laboratory |
//|                                   https://www.independentlab.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Independent Laboratory"
#property link     "https://www.independentlab.net"
#property version   "1.00"

//+------------------------------------------------------------------+
//| マジックナンバーが一致する最新チケットを操作対象とする。         |
//| さらにチケット番号も取得する。                                   |
//+------------------------------------------------------------------+
ulong get_latest_position_ticket(long magic) export {
   ulong ret_ticket = -1;  // 戻り値となるチケット番号を保存するための変数
   int position_total = PositionsTotal();  // ポジションの個数を保存する
   
   // 全ポジションについて (ポジション番号の大きい順に確認する =　最新順)
   for (int index = position_total - 1; index >= 0; index--) {
     // 注目しているポジションのチケット番号を取得する
     ulong ticket = PositionGetTicket(index);
     if (ticket == 0) {
         Print("Error: ポジションのチケット番号の取得に失敗しました (ポジション番号: " 
               + string(index) + ")");
         break;  // ポジションのチケット番号が取得できなかったため、処理は異常終了扱いとする
      }
      
      // 注目しているチケットのマジックナンバーが
      // このプログラムのマジックナンバーと一致することを確認する
      if (set_target_ticket_with_magic(ticket, magic)) {
         ret_ticket = ticket;  // 注目しているチケットの番号を戻り値として保存
         break;  // ポジションの確認処理は終了する
      }
   }
   
   // 最新のチケット番号を返す。チケットの検索に失敗した場合には自動的に-1が返される。
   return ret_ticket;
}


//+------------------------------------------------------------------+
//| 指定されたチケット番号のチケットを操作対象とする。               |
//| マジックナンバーの一致も確認する                                 |
//+------------------------------------------------------------------+
bool set_target_ticket_with_magic(ulong ticket, long magic) export {
   // 指定されたチケット番号のチケットを操作対象とする
   if (!PositionSelectByTicket(ticket)) {
      Print("Error: 操作対象チケットの設定に失敗しました (チケット番号: " 
            + string(ticket) + ")");
      return false;
   }
   
   // 操作対象にしたチケットのマジックナンバーを取得する
   long ticket_magic = 0;
   if (!PositionGetInteger(POSITION_MAGIC, ticket_magic)) {
      Print("Error: 操作対象のチケットからマジックナンバーを取得できませんでした (チケット番号: "
             + string(ticket) + ")");
      return false;
   }
   
   // 操作対象のチケットとこの自動売買プログラムのマジックナンバーが一致しない場合にはエラー
   if (ticket_magic != magic) {
      Print("Error: Invalid magic number: " + string(magic));
      return false;
   }
   
   // この自動売買プログラムのマジックナンバーを持つチケットを操作対象にできたため、成功とする。
   return true;
}

//+------------------------------------------------------------------+
//| SL/TP変更処理                                         |
//+------------------------------------------------------------------+
bool change_sl_tp_by_ticket(ulong ticket, double sl_point, double tp_point, long magic) export {
   MqlTradeRequest request;  // トレードの実行を要求するためのデータ構造
   MqlTradeResult result;   // トレードの実行結果を保存するためのデータ構造   
   ZeroMemory(request); // トレードの実行を要求するためのデータ構造に0を入れてリセットする
   ZeroMemory(result);  // トレードの実行結果を保存するためのデータ構造に0を入れてリセットする
   
   
   // 引数で指定された番号のチケットを操作対象とする。マジックナンバーの一致も同時に確認する。
   if (!set_target_ticket_with_magic(ticket, magic)) {
      Print("Error: 指定されたチケットを操作対象にできませんでした (チケット番号: " 
            + string(ticket) + ")");
      return false;
   }
   
   //--- 注文パラメータ
   string position_symbol = PositionGetString(POSITION_SYMBOL); // 操作対象のチケットの通貨ペア名
   int position_type = (int)PositionGetInteger(POSITION_TYPE);  // 操作対象のチケットが買い状態か売り状態か (= ポジションタイプ)
   
   double sl;  // ストップロスを保存するための変数
   double tp;  // テイクプロフィットを保存するための変数
   
   // 操作対象のチケットが買い状態の場合
   if (position_type == POSITION_TYPE_BUY) {
      // 引数で受け取ったSL/TPポイント幅をレート位置に変換する。結果は変数sl, tpに上書き保存される。
      sl_tp_calc_from_point(ORDER_TYPE_BUY, sl_point, tp_point, sl, tp);
   }
   // 操作対象のチケットが売り状態の場合
   else if (position_type == POSITION_TYPE_SELL) {
      // 引数で受け取ったSL/TPポイント幅をレート位置に変換する。結果は変数sl, tpに上書き保存される。
      sl_tp_calc_from_point(ORDER_TYPE_SELL, sl_point, tp_point, sl, tp);
   }
   else {
      Print("Error:操作対象のチケットの売り/買い状態を正しく認識できませんでした (ポジションタイプ: " 
            + string(position_type) + ")");
      return false;
   }

   //--- 操作パラメータの設定
   request.action = TRADE_ACTION_SLTP; // SL/TPを変更するための設定
   request.position = ticket;          // SL/TP位置の変更対象のチケット番号
   request.symbol = position_symbol;   // 対象の通貨ペア
   request.sl = sl;                    // 新たに設定するストップロスのレート位置
   request.tp = tp;                    // 新たに設定するテイクプロフィットのレート位置
   request.magic = magic;              // チケットに与えるマジックナンバー
   
   //--- SL/TP変更リクエストの送信
   if(!OrderSend(request,result)) {
      // SL/TP変更リクエストの送信に失敗した場合、エラーコードを出力する
      Print("Error: SL/TP位置の変更に失敗しました (エラーコード: " 
            + string(GetLastError()) + ")"); 
      return false;
   }
   // SL/TP変更に成功
   else {
      return true;
   }
}


//+------------------------------------------------------------------+
//| ストップロス(SL)/テイクプロフィット(TP) をポイント数から計算する                |
//+------------------------------------------------------------------+
bool sl_tp_calc_from_point(int order_type, double sl_point, double tp_point, double &sl, double &tp) export {
   double ask = 0;   // 現在の買いのレートを保存するための変数 
   double bid = 0;   // 現在の売りのレートを保存するための変数 
   double point = 0;  // 1ポイント当たりのレートを保存するための変数
   long digits = 0;   // レートの小数点以下の桁数を保存するための変数
   
   if (!SymbolInfoDouble(Symbol(), SYMBOL_ASK, ask) ||       // 現在の買いのレートを取得する
      !SymbolInfoDouble(Symbol(), SYMBOL_BID, bid) ||       // 現在の売りのレートを取得する
      !SymbolInfoDouble(Symbol(), SYMBOL_POINT, point) ||    // 1ポイント当たりのレートを取得する
      !SymbolInfoInteger(Symbol(), SYMBOL_DIGITS, digits)) {  // レートの小数点以下の桁数を取得する
      Print("Error: 通貨ペア情報の取得に失敗しました");
      return false;
   }
   
   // 買い注文のためのSL/TPをポイント数から計算する場合
   if (order_type == ORDER_TYPE_BUY) {
      // SL/TP位置の計算 (ただし，0 point以下が指定された場合はSL/TP設定をしない)
      double stop_buy_to_sell_point = sl_point * point;   // 注文が買い→売りのときのSLポイント幅をレート幅に変換する
      double limit_buy_to_sell_point = tp_point * point;  // 注文が買い→売りのときのTPポイント幅をレート幅に変換する
      sl = NormalizeDouble(ask - stop_buy_to_sell_point, (int)digits);   // SLレート幅をレート位置に変換する。小数点以下は現在の通貨ペアに合わせて丸める。      
      tp = NormalizeDouble(ask + limit_buy_to_sell_point, (int)digits);  // TPレート幅をレート位置に変換する。小数点以下は現在の通貨ペアに合わせて丸める。 
      
      // TPポイント幅として0以下が指定されたときは上記の計算はなかったことにする。SL幅についても同様。
      if (sl_point <= 0) { sl = 0; }
      if (tp_point <= 0) { tp = 0; }
      
      PrintFormat("sl: %f", sl_point);
   }
   // 売り注文のためのSL/TPをポイント数から計算する場合
   else if (order_type == ORDER_TYPE_SELL) {
      // SL/TP位置の計算 (ただし，0 point以下が指定された場合はSL/TP設定をしない)
      double stop_sell_to_buy_point = sl_point * point;   // 注文が売り→買いのときのSLポイント幅をレート幅に変換する
      double limit_sell_to_buy_point = tp_point * point;  // 注文が売り→買いのときのTPポイント幅をレート幅に変換する
      
      sl = NormalizeDouble(bid + stop_sell_to_buy_point, (int)digits);   // SLレート幅をレート位置に変換する。小数点以下は現在の通貨ペアに合わせて丸める。   
      tp = NormalizeDouble(bid - limit_sell_to_buy_point, (int)digits);  // TPレート幅をレート位置に変換する。小数点以下は現在の通貨ペアに合わせて丸める。 

      // TPポイント幅として0以下が指定されたときは上記の計算はなかったことにする。SL幅についても同様。
      if (sl_point <= 0) { sl = 0; }
      if (tp_point <= 0) { tp = 0; }
   }
   else {
      Print("Error: 注文の種類(売り/買い)の指定が不正です (注文の種類: " + string(order_type) + ")");
      return false;
   }
   
   
   return true;
}


//+------------------------------------------------------------------+
//| 注文処理                                                         |
//+------------------------------------------------------------------+
bool order_open(int order_type, double lot, int slippage, double sl, double tp, long magic) export {
   MqlTradeRequest request;  // トレードの実行を要求するためのデータ構造
   MqlTradeResult result;    // トレードの実行結果を保存するためのデータ構造
   
   ZeroMemory(request); // トレードの実行を要求するためのデータ構造に0を入れてリセットする
   ZeroMemory(result);  // トレードの実行結果を保存するためのデータ構造に0を入れてリセットする
   
   double ask;  // 現在の買いのレートを保存する変数
   double bid;  // 現在の売りのレートを保存する変数
   if (!SymbolInfoDouble(Symbol(), SYMBOL_ASK, ask) ||  // 現在の買いのレートを取得する
      !SymbolInfoDouble(Symbol(), SYMBOL_BID, bid)) {   // 現在の売りのレートを取得する
      // レート情報の取得に失敗した場合は、メッセージを表示してFalseを返す
      Print("Error: レート情報の取得に失敗しました");
      return false;
   }
   
   request.action = TRADE_ACTION_DEAL;   // 成り行き注文を出す設定をする
   request.symbol = Symbol();            // この自動売買プログラムを適用しているチャート画面の通貨ペア情報名を取得する
   request.volume = lot;                 // 売買するロット数を指定する
   request.type_filling = SYMBOL_FILLING_FOK; // XMTradingでの取引処理に対応させるための値を設定する
   
   // 引数として与えられたストップロスが0以上の場合は、取引時にストップロスを指定する
   if (sl > 0) {
      request.sl = sl;
   }
   
   // 引数として与えられたテイクプロフィットが0以上の場合は、取引時にテイクプロフィットを指定する
   if (tp > 0) {
      request.tp = tp;
   }

   request.deviation = slippage;   // 売買指定価格からの許容偏差
   request.magic = magic;          // ポジションに与えるマジックナンバー


   // 買い注文を出す場合
   if (order_type == ORDER_TYPE_BUY) {
      request.type = ORDER_TYPE_BUY;  // 注文の種類を買い注文に設定
      request.price = ask;            // 現在の買いのレートで注文する
      string message = "Buy " + "lot: " + string(lot) + " sl: " + string(request.sl) 
                       + " price: " + string(request.price) + " tp: " + string(request.tp);
      Print(message);
   }
   // 売り注文を出す場合
   else if (order_type == ORDER_TYPE_SELL) {
      request.type = ORDER_TYPE_SELL; // 注文の種類を売り注文に設定
      request.price = bid;            // 現在の売りのレートで注文する
      string message = "Sell " + "lot: " + string(lot) + " sl: " + string(request.sl) 
                       + " price: " + string(request.price) + " tp: " + string(request.tp);
      Print(message);
   }
   else {
      Print("Error: 注文の種類の指定が不正です: " + string(order_type));
      return false;
   }
   
      
   // 注文を送信する
   // 注文失敗時
   if (!OrderSend(request, result)) {  
      PrintFormat("Error: 新規注文の送信に失敗しました (エラーコード: %d、リターンコード: %d)", 
                  GetLastError(), result.retcode);
      return false;
   }
   // 注文成功時
   else {
      return true;
   }
}

//+------------------------------------------------------------------+
//| 決済処理                                                         |
//+------------------------------------------------------------------+
bool order_close(ulong ticket, int slippage, long magic) export {
   MqlTradeRequest request;  // トレードの実行を要求するためのデータ構造
   MqlTradeResult result;    // トレードの実行結果を保存するためのデータ構造
   
   ZeroMemory(request); // トレードの実行を要求するためのデータ構造に0を入れてリセットする
   ZeroMemory(result);  // トレードの実行結果を保存するためのデータ構造に0を入れてリセットする
   
   //--- 注文のパラメータ
   if (!PositionSelectByTicket(ticket)) {
      Print("Error: ポジションが選択状態になりませんでした@order_close (チケット番号: " + string(ticket) + ")");
      return false;
   }
   string position_symbol;          // シンボル
   long digits;                     // 小数点以下の桁数
   ulong magic_number_of_position;  // ポジションのマジックナンバー
   double volume;                   // ポジションボリューム
   long position_type;              // ポジションタイプ
   
   if (!PositionGetString(POSITION_SYMBOL, position_symbol) ||         // ポジションの通貨ペアを取得
      !SymbolInfoInteger(position_symbol, SYMBOL_DIGITS, digits) ||    // ポジションのpipsの小数点以下の桁数を取得
      !PositionGetInteger(POSITION_MAGIC, magic_number_of_position) || // ポジションのマジックナンバーを取得
      !PositionGetDouble(POSITION_VOLUME, volume) ||                   // ポジションのロット数を取得
      !PositionGetInteger(POSITION_TYPE, position_type)) {             // ポジションが売り状態なのか買い状態なのかを取得
      
      Print("Error: 通貨ペア情報の取得に失敗しました@order_close");
      return false;
   }
   
                
   //--- この自動売買プログラムとチケットでマジックナンバーが一致していない場合はクローズ失敗とする
   if (magic_number_of_position != magic) {
      return false;
   }
   
   request.action   = TRADE_ACTION_DEAL;    // 成り行き注文を出す設定をする
   request.position  = ticket;              // 操作対象のポジションチケットの番号
   request.symbol   = position_symbol;      // 操作対象のポジションチケットの通貨ペア
   request.volume   = volume;               // 操作対象のポジションチケットのロット数
   request.deviation = slippage;            // 売買指定価格からの許容偏差
   request.magic    = magic;                // ポジションのマジックナンバー
   request.type_filling = SYMBOL_FILLING_FOK;   // XMTradingでの取引処理に対応させるための値を設定する
   
   // Print("Ticket will be closed");
   //--- ポジションタイプによる注文タイプと価格の設定
   if (position_type == POSITION_TYPE_BUY) {                          // 保持しているポジションが買いの場合
      request.price = SymbolInfoDouble(position_symbol, SYMBOL_BID);  // 現在の売りのレートを取得
      request.type = ORDER_TYPE_SELL;                                 // 売り注文を出す設定をする
   }
   else if (position_type == POSITION_TYPE_SELL) {                    // 保持しているポジションが売りの場合
      request.price = SymbolInfoDouble(position_symbol, SYMBOL_ASK);  // 現在の買いのレートを取得
      request.type = ORDER_TYPE_BUY;                                  // 買い注文を出す設定をする
   }
   else {
      Print("Error: ポジションの売り/買い状態の情報が不正です@order_close (ポジションタイプ: " 
            + string(position_type) + ")");
   }
    
   //--- リクエストの送信
   if (!OrderSend(request,result)) {
       // 注文の送信に失敗した場合、エラーコードを表示
       PrintFormat("Error: ポジションのクローズに失敗しました (エラーコード: %d、リターンコード: %d)", 
                     GetLastError(), result.retcode);
       return false;
   }
   else {
      return true;  // 注文の実行に成功した場合はTrueを返す
   }
} 

//+------------------------------------------------------------------+
//| メッセージ送信                                                   |
//+------------------------------------------------------------------+
void send_message(bool enable_send_message, string message) export {
   if (enable_send_message) {
      bool result = SendNotification("[" + string(TimeCurrent()) + "] " + message);
      if (!result) {
         Print("Error: my send message " + string(GetLastError()));
      }
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   // 処理を実行したことを記録する変数。0=未実行、1=実行済み
   static int run_flag = 0;  
     
   //レートの更新毎に実行する
   // 処理を1回実行済みならば何もしないで関数を終了する。
   if (run_flag == 1) {
      return;
   }
   run_flag = 1;  // 1回実行したことを記録する
     
   // ---------- 1回のみ実行される処理 始まり ----------
   Print("実行しました");
   // ---------- 1回のみ実行される処理 終わり ----------

  }
//+------------------------------------------------------------------+
