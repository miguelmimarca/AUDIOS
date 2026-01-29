//+------------------------------------------------------------------+
//| Indicador_Control_Cierres_mimarca_v3.mq4                          |
//| Panel + líneas virtuales (SL/TP/P1/P2/BE/BE+) por ticket          |
//| Diseñado para trabajar con el EA "Gestor_Ordenes_mimarca_9"       |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window

input string ControlPrefix = "ControlCierres_";   // Debe coincidir con el EA
input double DefaultPartial1Percent = 50.0;
input double DefaultPartial2Percent = 30.0;

input int PanelX = -1; // -1 = centrar automaticamente
input int PanelY = 10;
input int BtnW   = 42;
input int BtnH   = 18;
input int Gap    = 4;

string BTN_ORD = "CC2_BTN_ORD";
string BTN_SL  = "CC2_BTN_SL";
string BTN_TP  = "CC2_BTN_TP";
string BTN_P1  = "CC2_BTN_P1";
string BTN_P2  = "CC2_BTN_P2";
string BTN_BE  = "CC2_BTN_BE";
string BTN_BEP = "CC2_BTN_BEP"; // BE+ (disparador: al tocar precio, el EA mueve el SL **virtual** a entrada)


string ORD_LIST_PREFIX = "CC2_ORDLBL_"; // + ticket

color orderColors[] = {clrDodgerBlue, clrOrangeRed, clrMediumSeaGreen, clrViolet, clrGold, clrAqua, clrHotPink};

int   g_selectedTicket = -1;
string g_symbol;

int OnInit()
{
   g_symbol = Symbol();
   CreateUI();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteAllObjects();
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
   return(rates_total);
}

void OnTimer()
{
   int tickets[];
   int n = GetOpenTicketsForSymbol(tickets);

   RefreshOrderLabels(tickets, n);

   // Mantener selección válida
   if(n == 0)
      g_selectedTicket = -1;
   else if(!TicketInArray(g_selectedTicket, tickets, n))
      g_selectedTicket = tickets[0];

   SyncLinesFromGlobals(tickets, n);
   UpdateButtonStates(tickets, n);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == BTN_SL)  ToggleLineForSelected("SL");
      else if(sparam == BTN_TP) ToggleLineForSelected("TP");
      else if(sparam == BTN_P1) ToggleLineForSelected("PL1");
      else if(sparam == BTN_P2) ToggleLineForSelected("PL2");
      else if(sparam == BTN_BEP) ToggleLineForSelected("BE");
      else if(sparam == BTN_BE)  SetSLToEntryForSelected();
      else if(StringFind(sparam, ORD_LIST_PREFIX) == 0)
      {
         int t = (int)StringToInteger(StringSubstr(sparam, StringLen(ORD_LIST_PREFIX)));
         if(t > 0) g_selectedTicket = t;
      }
   }

   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      // Si se mueve una línea, reflejarlo en variables globales
      UpdateGlobalsFromLine(sparam);
   }
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      UpdatePercentFromEdit(sparam);
   }
}


int GetPanelStartX()
{
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int x0 = PanelX;
   if(x0 < 0)
   {
      int wORD = BtnW + 8;
      int wSL  = BtnW;
      int wTP  = BtnW;
      int wP1  = BtnW;
      int wP2  = BtnW;
      int wBE  = BtnW;
      int wBEP = BtnW + 6;
      int totalW = wORD + Gap + wSL + Gap + wTP + Gap + wP1 + Gap + wP2 + Gap + wBE + Gap + wBEP;
      x0 = (chartW - totalW) / 2;
      if(x0 < 5) x0 = 5;
   }
   return x0;
}

// ----------------------------- UI ----------------------------------

void CreateUI()
{
   // Posicionar arriba y centrado (como el indicador de referencia).
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int x0 = PanelX;
   if(x0 < 0)
   {
      int wORD = BtnW + 8;
      int wSL  = BtnW;
      int wTP  = BtnW;
      int wP1  = BtnW;
      int wP2  = BtnW;
      int wBE  = BtnW;
      int wBEP = BtnW + 6;

      int totalW = wORD + Gap + wSL + Gap + wTP + Gap + wP1 + Gap + wP2 + Gap + wBE + Gap + wBEP;
      x0 = (chartW - totalW) / 2;
      if(x0 < 5) x0 = 5;
   }

   int x = x0;
   CreateButton(BTN_ORD, x, PanelY, BtnW+8, BtnH, "ORD"); x += (BtnW+8) + Gap;
   CreateButton(BTN_SL,  x, PanelY, BtnW,   BtnH, "SL");  x += BtnW + Gap;
   CreateButton(BTN_TP,  x, PanelY, BtnW,   BtnH, "TP");  x += BtnW + Gap;
   CreateButton(BTN_P1,  x, PanelY, BtnW,   BtnH, "P1");  x += BtnW + Gap;
   CreateButton(BTN_P2,  x, PanelY, BtnW,   BtnH, "P2");  x += BtnW + Gap;
   CreateButton(BTN_BE,  x, PanelY, BtnW,   BtnH, "BE");  x += BtnW + Gap;
   CreateButton(BTN_BEP, x, PanelY, BtnW+6, BtnH, "BE+");
}




void CreateButton(string name, int x, int y, int w, int h, string text)
{
   if(ObjectFind(0, name) >= 0) return;
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_RAISED);
}

void SetButtonEnabled(string name, bool enabled)
{
   if(ObjectFind(0, name) < 0) return;
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetInteger(0, name, OBJPROP_COLOR, enabled ? clrWhite : clrSilver);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, enabled ? clrDimGray : clrGray);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, enabled);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

void RefreshOrderLabels(const int &tickets[], int n)
{
   // Tickets como "cajas" (botones) con ancho fijo para que NO se solapen.
   // No hacemos salto de línea (normalmente habrá 1-2 órdenes por símbolo).
   int x = GetPanelStartX();
   int y = PanelY + BtnH + 6;

   int boxW = 90;   // ancho suficiente para 8 dígitos + margen
   int boxH = 16;
   int boxGap = 8;

   // Limpiar tickets antiguos que ya no existen
   int total = ObjectsTotal(0,-1,-1);
   for(int i = total-1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, ORD_LIST_PREFIX) == 0)
      {
         int t = (int)StringToInteger(StringSubstr(name, StringLen(ORD_LIST_PREFIX)));
         if(!TicketInArray(t, tickets, n))
            ObjectDelete(0, name);
      }
   }

   // Crear/actualizar los tickets actuales
   for(int k=0;k<n;k++)
   {
      int ticket = tickets[k];
      string name = ORD_LIST_PREFIX + IntegerToString(ticket);

      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);

      bool selected = (ticket == g_selectedTicket);
      color c = GetOrderColor(ticket);

      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, boxW);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, boxH);

      // Texto / estilo
      ObjectSetString(0, name, OBJPROP_TEXT, (selected ? "> " : "  ") + IntegerToString(ticket));
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, name, OBJPROP_COLOR, c);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, selected ? clrSlateGray : clrBlack);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, selected ? BORDER_RAISED : BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);

      x += boxW + boxGap;
   }
}

void UpdateButtonStates(const int &tickets[], int n)
{
   bool hasOrders = (n > 0) && (g_selectedTicket > 0);

   // ORD es solo cabecera, lo dejamos siempre visible
   SetButtonEnabled(BTN_SL,  hasOrders);
   SetButtonEnabled(BTN_TP,  hasOrders);
   SetButtonEnabled(BTN_P1,  hasOrders);
   SetButtonEnabled(BTN_P2,  hasOrders);
   SetButtonEnabled(BTN_BEP, hasOrders);

   // BE puede estar inactivo si SL virtual ya está exactamente en entrada
   bool beEnabled = hasOrders;
   if(hasOrders)
   {
      double entry = GetOrderEntry(g_selectedTicket);
      if(entry > 0)
      {
         double slv = GetGV(ControlKey(g_selectedTicket,"SL"), 0.0);
         bool slActive = (GetGV(ControlKey(g_selectedTicket,"SLActive"), 0.0) > 0.0);
         if(slActive && MathAbs(slv - entry) <= (Point*0.5))
            beEnabled = false;
      }
   }
   SetButtonEnabled(BTN_BE, beEnabled);
}



// --------------------------- Tickets --------------------------------

int GetOpenTicketsForSymbol(int &tickets[])
{
   ArrayResize(tickets, 0);
   int count = 0;

   // 1) Obtener todos los tickets del símbolo
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != g_symbol) continue;

      int ticket = OrderTicket();
      // 2) Filtrar: si el EA ya está gestionando este ticket, tendrá al menos una GV con el prefijo.
      //    Si no existe ninguna, igualmente lo mostramos (para que puedas crear líneas).
      ArrayResize(tickets, count+1);
      tickets[count] = ticket;
      count++;
   }

   return count;
}

bool TicketInArray(int ticket, const int &arr[], int n)
{
   if(ticket <= 0) return false;
   for(int i=0;i<n;i++) if(arr[i]==ticket) return true;
   return false;
}

double GetOrderEntry(int ticket)
{
   if(ticket<=0) return 0.0;
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return 0.0;
   return OrderOpenPrice();
}

double GetOrderBrokerSL(int ticket)
{
   if(ticket<=0) return 0.0;
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return 0.0;
   return OrderStopLoss();
}

double GetOrderBrokerTP(int ticket)
{
   if(ticket<=0) return 0.0;
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return 0.0;
   return OrderTakeProfit();
}

color GetOrderColor(int ticket)
{
   int idx = ticket % ArraySize(orderColors);
   return orderColors[idx];

}

string PrettySuffix(string suffix)
{
   if(suffix=="PL1") return "P1";
   if(suffix=="PL2") return "P2";
   if(suffix=="BE")  return "BE+";
   return suffix;
}

// ----------------------- Líneas / Globals ----------------------------

string ControlKey(int ticket, string suffix)
{
   return ControlPrefix + g_symbol + "_" + IntegerToString(ticket) + "_" + suffix;
}

string LineName(int ticket, string suffix) // suffix: SL,TP,PL1,PL2,BE
{
   return "CC2_" + g_symbol + "_" + IntegerToString(ticket) + "_" + suffix;
}

string LineLabelName(int ticket, string suffix)
{
   return "CC2LBL_" + g_symbol + "_" + IntegerToString(ticket) + "_" + suffix;
}

double GetGV(string key, double def)
{
   if(GlobalVariableCheck(key)) return GlobalVariableGet(key);
   return def;
}

void SetGV(string key, double val)
{
   GlobalVariableSet(key, val);
}

void DelGV(string key)
{
   if(GlobalVariableCheck(key)) GlobalVariableDel(key);
}

bool IsLineActiveSuffix(string suffix, string &activeKeyOut, string &valueKeyOut)
{
   // Mapeo EA
   if(suffix=="SL"){ activeKeyOut="SLActive"; valueKeyOut="SL"; return true; }
   if(suffix=="TP"){ activeKeyOut="TPActive"; valueKeyOut="TP"; return true; }
   if(suffix=="PL1"){ activeKeyOut="P1Active"; valueKeyOut="PL1"; return true; }
   if(suffix=="PL2"){ activeKeyOut="P2Active"; valueKeyOut="PL2"; return true; }
   if(suffix=="BE"){ activeKeyOut="BELActive"; valueKeyOut="BE"; return true; }
   return false;
}

void ToggleLineForSelected(string suffix)
{
   if(g_selectedTicket<=0) return;

   string activeSuffix, valueSuffix;
   if(!IsLineActiveSuffix(suffix, activeSuffix, valueSuffix)) return;

   string ln = LineName(g_selectedTicket, suffix);
   string lkVal = ControlKey(g_selectedTicket, valueSuffix);
   string lkAct = ControlKey(g_selectedTicket, activeSuffix);

   bool exists = (ObjectFind(0, ln) >= 0);
   bool active = (GetGV(lkAct,0.0) > 0.0);

   if(exists || active)
   {
      // Apagar
      ObjectDelete(0, ln);
      ObjectDelete(0, LineLabelName(g_selectedTicket, suffix));
      if(suffix=="PL1" || suffix=="PL2") DeletePercentEdit(g_selectedTicket, suffix);
      DelGV(lkVal);
      DelGV(lkAct);
      return;
   }

   // Encender en nivel por defecto
   double price = 0.0;
   if(suffix=="SL") price = GetOrderBrokerSL(g_selectedTicket);
   else price = GetOrderBrokerTP(g_selectedTicket);

   if(price <= 0.0)
   {
      double entry = GetOrderEntry(g_selectedTicket);
      price = (entry>0 ? entry : (Bid>0?Bid:Ask));
   }

   // P1/P2: aseguramos % por defecto si no existe
   if(suffix=="PL1" && !GlobalVariableCheck(ControlKey(g_selectedTicket,"PL1Pct")))
      SetGV(ControlKey(g_selectedTicket,"PL1Pct"), DefaultPartial1Percent);
   if(suffix=="PL2" && !GlobalVariableCheck(ControlKey(g_selectedTicket,"PL2Pct")))
      SetGV(ControlKey(g_selectedTicket,"PL2Pct"), DefaultPartial2Percent);

   CreateOrMoveLine(g_selectedTicket, suffix, price);
   if(suffix=="PL1") EnsurePercentEdit(g_selectedTicket, "PL1Pct", "PL1");
   if(suffix=="PL2") EnsurePercentEdit(g_selectedTicket, "PL2Pct", "PL2");
   SetGV(lkVal, price);
   SetGV(lkAct, 1);
}

void SetSLToEntryForSelected()
{
   if(g_selectedTicket<=0) return;
   double entry = GetOrderEntry(g_selectedTicket);
   if(entry<=0) return;

   // Crear o mover SL line a entrada y activar SLActive
   CreateOrMoveLine(g_selectedTicket, "SL", entry);
   SetGV(ControlKey(g_selectedTicket,"SL"), entry);
   SetGV(ControlKey(g_selectedTicket,"SLActive"), 1);

   // Mantener % si existen (no toca)
}

void CreateOrMoveLine(int ticket, string suffix, double price)
{
   string name = LineName(ticket, suffix);
   color c = GetOrderColor(ticket);

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_STYLE, (suffix=="SL"||suffix=="TP") ? STYLE_SOLID : (suffix=="BE" ? STYLE_DASH : STYLE_DOT));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);

   // Etiqueta en el gráfico (OBJ_TEXT) para ver ticket + tipo
   CreateOrUpdateLineLabel(ticket, suffix, price, c);
}

void CreateOrUpdateLineLabel(int ticket, string suffix, double price, color c)
{
   string lbl = LineLabelName(ticket, suffix);
   datetime t = TimeCurrent();

   if(ObjectFind(0, lbl) < 0)
      ObjectCreate(0, lbl, OBJ_TEXT, 0, t, price);

   ObjectSetInteger(0, lbl, OBJPROP_COLOR, c);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, lbl, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lbl, OBJPROP_BACK, false);

   ObjectMove(0, lbl, 0, t, price);
   ObjectSetString(0, lbl, OBJPROP_TEXT, IntegerToString(ticket) + " " + PrettySuffix(suffix));
}

// -------------------- % editable junto a líneas P1/P2 --------------------

string PercentEditName(int ticket, string lineSuffix)
{
   // lineSuffix: "PL1" o "PL2"
   return LineName(ticket, lineSuffix + "PCT"); // CC2_<sym>_<ticket>_PL1PCT
}

void DeletePercentEdit(int ticket, string lineSuffix)
{
   string n = PercentEditName(ticket, lineSuffix);
   if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
}

void EnsurePercentEdit(int ticket, string pctKeySuffix, string lineSuffix)
{
   // pctKeySuffix: "PL1Pct" o "PL2Pct"
   string key = ControlKey(ticket, pctKeySuffix);

   double pct = (pctKeySuffix=="PL2Pct") ? DefaultPartial2Percent : DefaultPartial1Percent;
   if(GlobalVariableCheck(key)) pct = GlobalVariableGet(key);
   else GlobalVariableSet(key, pct); // asegurar existencia

   string lineName = LineName(ticket, lineSuffix);
   if(ObjectFind(0, lineName) < 0) return;

   double price = ObjectGetDouble(0, lineName, OBJPROP_PRICE);
   if(price <= 0) return;

   // Convertir time/price a coordenadas pantalla para "pegar" el edit a la línea
   int x=0, y=0;
   datetime t = TimeCurrent();
   if(!ChartTimePriceToXY(0, 0, t, price, x, y))
      return;

   string obj = PercentEditName(ticket, lineSuffix);
   color bg = GetOrderColor(ticket);

   if(ObjectFind(0, obj) < 0)
   {
      ObjectCreate(0, obj, OBJ_EDIT, 0, 0, 0);
      ObjectSetInteger(0, obj, OBJPROP_XSIZE, 45);
      ObjectSetInteger(0, obj, OBJPROP_YSIZE, 16);
      ObjectSetInteger(0, obj, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, obj, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, obj, OBJPROP_READONLY, false);
      ObjectSetInteger(0, obj, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, obj, OBJPROP_HIDDEN, false);
   }
   else
   {
      ObjectSetInteger(0, obj, OBJPROP_BGCOLOR, bg);
   }

   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x + 10);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y - 8);
   ObjectSetString(0, obj, OBJPROP_TEXT, DoubleToString(pct, 1));
}

void UpdatePercentFromEdit(string objName)
{
   // Espera nombres: CC2_<sym>_<ticket>_PL1PCT / PL2PCT
   if(StringFind(objName, "CC2_"+g_symbol+"_") != 0) return;
   if(StringFind(objName, "_PL1PCT") < 0 && StringFind(objName, "_PL2PCT") < 0) return;

   string parts[];
   int n = StringSplit(objName, '_', parts);
   if(n < 4) return;

   int ticket = (int)StringToInteger(parts[2]);
   string suff = parts[3]; // "PL1PCT" o "PL2PCT"

   string txt = ObjectGetString(0, objName, OBJPROP_TEXT);
   double pct = StrToDouble(txt);
   if(pct < 0) pct = 0;
   if(pct > 100) pct = 100;

   if(suff=="PL1PCT")
      GlobalVariableSet(ControlKey(ticket, "PL1Pct"), pct);
   else if(suff=="PL2PCT")
      GlobalVariableSet(ControlKey(ticket, "PL2Pct"), pct);

   // Re-pintar (por si el usuario metió algo raro)
   EnsurePercentEdit(ticket, (suff=="PL1PCT" ? "PL1Pct" : "PL2Pct"), (suff=="PL1PCT" ? "PL1" : "PL2"));
}

void UpdateGlobalsFromLine(string objName)
{
   // Detectar si es una de nuestras líneas
   if(StringFind(objName, "CC2_"+g_symbol+"_") != 0) return;

   // Parse: CC2_<sym>_<ticket>_<suffix>
   string parts[];
   int n = StringSplit(objName, '_', parts);
   if(n < 4) return;
   int ticket = (int)StringToInteger(parts[2]);
   string suffix = parts[3];

   double price = ObjectGetDouble(0, objName, OBJPROP_PRICE);

   string activeSuffix, valueSuffix;
   if(!IsLineActiveSuffix(suffix, activeSuffix, valueSuffix)) return;

   SetGV(ControlKey(ticket, valueSuffix), price);
   SetGV(ControlKey(ticket, activeSuffix), 1);

   // Mantener etiqueta sincronizada
   CreateOrUpdateLineLabel(ticket, suffix, price, GetOrderColor(ticket));
   if(suffix=="PL1") EnsurePercentEdit(ticket, "PL1Pct", "PL1");
   if(suffix=="PL2") EnsurePercentEdit(ticket, "PL2Pct", "PL2");
}

void SyncLinesFromGlobals(const int &tickets[], int n)
{
   // 1) Para tickets activos: crear/mover/eliminar líneas según GV active
   for(int i=0;i<n;i++)
   {
      int ticket = tickets[i];

      SyncOne(ticket, "SL", "SLActive", "SL");
      SyncOne(ticket, "TP", "TPActive", "TP");
      SyncOne(ticket, "PL1", "P1Active", "PL1");
      SyncOne(ticket, "PL2", "P2Active", "PL2");
      SyncOne(ticket, "BE", "BELActive", "BE");
   }

   // 2) Limpiar líneas/labels de tickets que ya no existen en el símbolo
   CleanupOrphanObjects(tickets, n);
}

void SyncOne(int ticket, string lineSuffix, string activeSuffix, string valueSuffix)
{
   string kAct = ControlKey(ticket, activeSuffix);
   string kVal = ControlKey(ticket, valueSuffix);

   bool active = (GetGV(kAct, 0.0) > 0.0) && GlobalVariableCheck(kVal);
   string ln = LineName(ticket, lineSuffix);
   string lbl = LineLabelName(ticket, lineSuffix);

   if(active)
   {
      double price = GetGV(kVal, 0.0);
      if(price > 0.0)
         CreateOrMoveLine(ticket, lineSuffix, price);
      // P1/P2: asegurar % editable junto a la línea
      if(lineSuffix=="PL1") EnsurePercentEdit(ticket, "PL1Pct", "PL1");
      if(lineSuffix=="PL2") EnsurePercentEdit(ticket, "PL2Pct", "PL2");
   }
   else
   {
      if(ObjectFind(0, ln) >= 0) ObjectDelete(0, ln);
      if(ObjectFind(0, lbl) >= 0) ObjectDelete(0, lbl);
      if(lineSuffix=="PL1") DeletePercentEdit(ticket, "PL1");
      if(lineSuffix=="PL2") DeletePercentEdit(ticket, "PL2");
   }
}

void CleanupOrphanObjects(const int &tickets[], int n)
{
   int total = ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--)
   {
      string name = ObjectName(0,i);

      // Líneas
      if(StringFind(name, "CC2_"+g_symbol+"_") == 0)
      {
         string parts[];
         int m = StringSplit(name, '_', parts);
         if(m>=4)
         {
            int ticket = (int)StringToInteger(parts[2]);
            if(!TicketInArray(ticket, tickets, n))
               ObjectDelete(0, name);
         }
      }

      // Labels de líneas
      if(StringFind(name, "CC2LBL_"+g_symbol+"_") == 0)
      {
         string parts2[];
         int m2 = StringSplit(name, '_', parts2);
         if(m2>=4)
         {
            int ticket2 = (int)StringToInteger(parts2[2]);
            if(!TicketInArray(ticket2, tickets, n))
               ObjectDelete(0, name);
         }
      }
   }
}

void DeleteAllObjects()
{
   // borra botones
   ObjectDelete(0, BTN_ORD);
   ObjectDelete(0, BTN_SL);
   ObjectDelete(0, BTN_TP);
   ObjectDelete(0, BTN_P1);
   ObjectDelete(0, BTN_P2);
   ObjectDelete(0, BTN_BE);
   ObjectDelete(0, BTN_BEP);

   // borra etiquetas de tickets, líneas y etiquetas asociadas
   int total = ObjectsTotal(0,-1,-1);
   for(int j=total-1;j>=0;j--)
   {
      string name = ObjectName(0,j);
      if(StringFind(name, ORD_LIST_PREFIX)==0 ||
         StringFind(name, "CC2_"+g_symbol+"_")==0 ||
         StringFind(name, "CC2LBL_"+g_symbol+"_")==0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+---------------------------------------------------------------+
