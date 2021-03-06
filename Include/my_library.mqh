//+------------------------------------------------------------------+
//|                           Copyright 2021, Independent Laboratory |
//|                                   https://www.independentlab.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Independent Laboratory"
#property link      "https://www.independentlab.net"
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
#import "my_library.ex5"
   // 最新のポジションを操作対象とし、チケット番号を取得する。マジックナンバーの一致も確認する
   ulong get_latest_position_ticket(long magic);
   
   // ポジションチケットを操作対象とする。マジックナンバーの一致も確認する
   bool set_target_ticket_with_magic(ulong ticket, long magic);
   
   // SL/TP変更処理
   bool change_sl_tp_by_ticket(ulong ticket, double sl_point, double tp_point, long magic);
   
   // SL/TPをポイント数から計算する
   bool sl_tp_calc_from_point(int order_type, double sl_point, double tp_point, double &sl, double &tp);
   
   // 注文処理
   bool order_open(int order_type, double lot, int slippage, double sl, double tp, long magic);
   
   // 決済注文
   bool order_close(ulong ticket, int slippage, long magic);
   
   // メッセージ送信
   void send_message(bool enable_send_message, string msg);
#import
//+------------------------------------------------------------------+
