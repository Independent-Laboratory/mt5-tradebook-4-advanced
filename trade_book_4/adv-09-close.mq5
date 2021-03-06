//+------------------------------------------------------------------+
//|                           Copyright 2021, Independent Laboratory |
//|                                   https://www.independentlab.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, Independent Laboratory"
#property link      "https://www.independentlab.net"
#property version   "1.00"
#include <my_library.mqh>

long magic = 101010;  // このプログラムのマジックナンバー

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
      bool result;
      double sl_point_setting = 200;  // ストップロスのポイント幅
      double tp_point_setting = 300;  // テイクプロフィットのポイント幅
      double sl = 0;  // ストップロスのレートを保存するための変数
      double tp = 0;  // テイクプロフィットのレートを保存するための変数
      
      // 引数1: 買い or 売り
      // 引数2: ストップロスのポイント数
      // 引数3: テイクプロフィットのポイント数
      // 引数4: ストップロスのレートの保存先
      // 引数5: テイクプロフィットのレートの保存先
      sl_tp_calc_from_point(ORDER_TYPE_BUY, sl_point_setting, tp_point_setting, sl, tp);
      
      // 引数1: 買い or 売り
      // 引数2: ロット数
      // 引数3: スリッページ
      // 引数4: ストップロス
      // 引数5: テイクプロフィット
      // 引数6: マジックナンバー
      result = order_open(ORDER_TYPE_BUY, 0.1, 1, sl, tp, magic);
      
      // 引数1: 買い or 売り
      // 引数2: ストップロスのポイント数
      // 引数3: テイクプロフィットのポイント数
      // 引数4: ストップロスのレートの保存先
      // 引数5: テイクプロフィットのレートの保存先
      // sl_tp_calc_from_point(ORDER_TYPE_SELL, sl_point_setting, tp_point_setting, sl, tp);
      
      // 引数1: 買い or 売り
      // 引数2: ロット数
      // 引数3: スリッページ
      // 引数4: ストップロス
      // 引数5: テイクプロフィット
      // 引数6: マジックナンバー
      // result = order_open(ORDER_TYPE_SELL, 0.1, 1, sl, tp, magic);

      if (result != true) {
         Print("注文に失敗しました");
         return;
      }
      
      // 最新チケットを操作対象に設定し、そのチケットの番号を取得する      
      ulong ticket = 0;  // チケット番号を保存するための変数
      ticket = get_latest_position_ticket(magic);
      if (ticket > 0) {
         Print("最新チケットの番号を取得しました (チケット番号: " + string(ticket) + ")");
      }
      
      int seconds = 10;  // 10秒待つ
      Sleep(seconds * 1000);  // 1000ミリ秒 = 1秒
      
      // ストップロスとテイクプロフィットの幅を広げる
      sl_point_setting += 100;
      tp_point_setting += 100;
      
      bool result_of_sltp_change;  // SL/TP変更処理の成功/失敗を保存するための変数
      
      // ストップロスとテイクプロフィットの変更
      // 引数1: 操作対象のチケット番号
      // 引数2: ストップロスのポイント幅
      // 引数3: テイクプロフィットのポイント幅
      // 引数4: このプログラムのマジックナンバー
      result_of_sltp_change 
         = change_sl_tp_by_ticket(ticket, sl_point_setting, tp_point_setting, magic);
      
      // ストップロスとテイクプロフィットの変更結果を確認
      if (result_of_sltp_change != true) {
         Print("SL/TPの変更処理に失敗しました");
         return;
      }
      
      Sleep(seconds * 1000);  // 10秒待つ
      
      // ポジションをクローズ
      // 引数1: 操作対象のチケット番号
      // 引数2: スリッページ
      // 引数3: このプログラムのマジックナンバー
      order_close(ticket, 1, magic);

      // ---------- 1回のみ実行される処理 終わり ----------

  }
//+------------------------------------------------------------------+
