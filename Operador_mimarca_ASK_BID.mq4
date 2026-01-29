//+------------------------------------------------------------------+
//|                                          El definitivo Oper_mimarca.mq4 |
//|                                  Copyright 2024, MetaQuotes Software Corp. |
//|                                             https://www.metaquotes.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"
#property strict

// Incluir las librerías necesarias
// En MQL4 no usamos Trade.mqh ni PositionInfo.mqh
//#include <Trade\Trade.mqh>
//#include <Trade\PositionInfo.mqh>

// En MQL4 no podemos crear estos objetos
//CTrade trade;
//CPositionInfo positionInfo;

// Inputs para el control de riesgo
input double RiskPercent = 1.0;     // Riesgo por operación (%) - Valor inicial
input double MinLot = 0.01;         // Lote mínimo
input double MaxLot = 1000.0;        // Lote máximo
input int    MagicNumber = 12345;   // Número Mágico
input double SpreadMultiplier = 1.5; // Multiplicador de compensación de spread

// Inputs para las líneas
input color LineColorBuy = clrBlue;      // Color línea compra
input color LineColorSell = clrRed;      // Color línea venta
input color LineColorSL = clrIndianRed;        // Color línea Stop Loss
input color LineColorTP = clrDarkSeaGreen;      // Color línea Take Profit

// Variables para las líneas
string entryLine = "";
string slLine = "";
string tpLine = "";

// Variables para los botones de la primera fila
string buttonRisk = "ButtonRisk";         // Botón de Riesgo
string buttonSL = "ButtonSL";             // Botón de Stop Loss
string buttonTP = "ButtonTP";             // Botón de Take Profit
string buttonApply = "ButtonApply";       // Botón de Aplicar
string buttonCancel = "ButtonCancel";     // Botón de Cancelar
string buttonExecute = "ButtonExecute";    // Botón de Ejecutar
string buttonMarket = "ButtonMarket";      // Botón de Market

// Variables para los botones y controles de la segunda fila
string buttonSync = "ButtonSync";          // Botón de Sincronización
string buttonSLLevel = "ButtonSLLevel";    // Cuadro de texto para nivel SL
string buttonTPLevel = "ButtonTPLevel";    // Cuadro de texto para nivel TP
string buttonEntryLevel = "ButtonEntryLevel"; // Cuadro de texto para nivel Entry
string buttonLotSize = "ButtonLotSize";    // Cuadro de texto para el lotaje

// Variables para los botones de la tercera fila
string buttonSLPreview = "ButtonSLPreview";     // Botón preview SL
string buttonTPPreview = "ButtonTPPreview";     // Botón preview TP
string buttonEntryPreview = "ButtonEntryPreview"; // Botón preview Entry

// Variables para etiquetas
string labelSL = "LabelSL";               // Etiqueta para SL
string labelTP = "LabelTP";               // Etiqueta para TP
string labelLot = "LabelLot";             // Etiqueta para lotaje
string labelMarketLot = "LabelMarketLot"; // Etiqueta para lotaje de Market
string labelTPMessage = "Trade_TPMessage";  // Nombre de la etiqueta para mensajes de TP
string labelSpread = "LabelSpread";       // Etiqueta para mostrar el spread

// Variable para el prefijo de variables globales
string GLOBAL_VAR_PREFIX = "TradeExpert_";

// Variables para el estado de los botones
bool slActive = false;
bool tpActive = false;
bool readyToApply = false;
double memorizedPrice = 0;

// Variables para almacenar los precios
double storedEntryPrice = 0;
double storedSLPrice = 0;
double storedTPPrice = 0;

// Variable interna para el riesgo actual
double currentRiskPercent; 

// Variables para los pips predeterminados
input int DefaultPipDistance = 20;  // Distancia predeterminada en pips

// Variables para dimensiones y posiciones
int xStart = 10;      // Posición inicial X
int yPos = 10;        // Posición inicial Y
int buttonWidth = 45; // Ancho del botón
int buttonHeight = 15; // Alto del botón
int spacing = 5;      // Espacio entre botones
int yPos2, yPos3;     // Posiciones Y para las filas 2 y 3

//+------------------------------------------------------------------+
//| Genera nombres únicos para los objetos del gráfico                |
//+------------------------------------------------------------------+
string GetUniqueObjectName(string baseName)
{
    // Usar el símbolo en lugar del ID del gráfico para hacer el nombre único
    return baseName + "_" + Symbol();
}

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    // Configurar el objeto de trading
    // En MQL4 no tenemos el objeto trade, estas líneas se omiten
    //trade.SetExpertMagicNumber(123456);
    //trade.SetMarginMode();
    //trade.SetTypeFillingBySymbol(_Symbol);
    
    // Inicializar riesgo interno con el valor del input
    currentRiskPercent = RiskPercent;    

    // Inicializar nombres de líneas con valores únicos para este gráfico
    entryLine = GetUniqueObjectName("Trade_Entry");
    slLine = GetUniqueObjectName("Trade_SL");
    tpLine = GetUniqueObjectName("Trade_TP");
    
    // Habilitar eventos del gráfico
    ChartSetInteger(0, CHART_MOUSE_SCROLL, true);    // Habilitar scroll del mouse
    ChartSetInteger(0, CHART_DRAG_TRADE_LEVELS, true);  // Habilitar arrastre de niveles
    ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);  // Habilitar creación de objetos
    ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);  // Habilitar eliminación de objetos
    // Mantener objetos visibles en todas las temporalidades
    ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, true);
    ChartSetInteger(0, CHART_FOREGROUND, false);
    
    // Crear botones
    CreateButtons();
    
    // Habilitar propiedades del chart
    ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
    ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, true);
    ChartSetString(0, CHART_COMMENT, "");  // Limpiar comentarios del chart
    
    // Configurar el timer a 1 segundo
    EventKillTimer();  // Primero matamos cualquier timer existente
    EventSetTimer(1);  // Establecer el timer a 1 segundo    
    // Restaurar el estado después de la inicialización
    RestoreGlobalState();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Si el motivo es cambio de timeframe, guardar el estado
    if(reason == REASON_CHARTCHANGE)
    {
        Print("Cambio de timeframe detectado, guardando estado...");
        SaveGlobalState();
    }
    
    // Eliminar objetos
    ObjectDelete(0, buttonRisk);
    ObjectDelete(0, buttonSL);
    ObjectDelete(0, buttonTP);
    ObjectDelete(0, buttonApply);
    ObjectDelete(0, buttonCancel);
    ObjectDelete(0, buttonExecute);
    ObjectDelete(0, buttonMarket);
    
    ObjectDelete(0, buttonSLLevel);
    ObjectDelete(0, buttonTPLevel);
    ObjectDelete(0, buttonEntryLevel);
    ObjectDelete(0, buttonLotSize);
    
    ObjectDelete(0, buttonSync);
    ObjectDelete(0, buttonSLPreview);
    ObjectDelete(0, buttonTPPreview);
    ObjectDelete(0, buttonEntryPreview);
    
    // Eliminar el label del spread
    ObjectDelete(0, labelSpread);
    
    // Solo eliminar las líneas y variables globales si no es un cambio de timeframe
    if(reason != REASON_CHARTCHANGE)
    {
        if(entryLine != "") ObjectDelete(0, entryLine);
        if(slLine != "") ObjectDelete(0, slLine);
        if(tpLine != "") ObjectDelete(0, tpLine);
        
        // Eliminar variables globales
        GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_EntryPrice");
        GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_SLPrice");
        GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_TPPrice");
        GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_SLActive");
        GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_TPActive");
        GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_LotSize");
        GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_SLPreview");
        GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_TPPreview");
        GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_EntryPreview");
        GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_RiskPercent");
    }
    
    EventKillTimer(); // Detener el timer
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Calcular el tamaño del lote basado en el riesgo                   |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double slPrice)
{
    // Usar currentRiskPercent en lugar de RiskPercent
    double riskAmount = AccountBalance() * (currentRiskPercent / 100.0);  // AccountInfoDouble(ACCOUNT_BALANCE) en MQL5
    double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);        // SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) en MQL5
    double pipSize = Point;                                        // SymbolInfoDouble(_Symbol, SYMBOL_POINT) en MQL5
    
    // Calcular distancia al SL en pips
    double slDistance = MathAbs(entryPrice - slPrice) / pipSize;
    
    // Calcular tamaño del lote
    double lotSize = riskAmount / (slDistance * pipValue);
    
    // Ajustar al tamaño de lote permitido
    lotSize = MathMin(MaxLot, MathMax(MinLot, lotSize));
    lotSize = NormalizeDouble(lotSize, 2);
    
    return lotSize;
}


//+------------------------------------------------------------------+
//| Calcular lote específicamente para operaciones a mercado         |
//+------------------------------------------------------------------+
double CalculateMarketLotSize(double marketPrice, double slPrice)
{
    double riskAmount, lotSize;
    
    // Evitar divisiones por cero
    if(marketPrice == 0 || slPrice == 0 || marketPrice == slPrice)
        return 0.01; // Lote mínimo por defecto
    
    double riskPips = MathAbs(marketPrice - slPrice) / Point;
    
    // Evitar divisiones por valores muy pequeños
    if(riskPips < 1)
        return 0.01;
    
    double accountEquity = AccountEquity();
    double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    
    // Calcular el monto de riesgo basado en el porcentaje de riesgo
    riskAmount = (accountEquity * currentRiskPercent) / 100.0;
    
    // Calcular tamaño del lote basado en riesgo
    lotSize = NormalizeDouble(riskAmount / (riskPips * tickValue), 2);
    
    // Asegurar que no excede el lote máximo y no es menor que el mínimo
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    
    if(lotSize < minLot)
        lotSize = minLot;
    if(lotSize > maxLot)
        lotSize = maxLot;
    
    // Ajustar al paso de lote correcto
    lotSize = NormalizeDouble(lotSize / lotStep, 0) * lotStep;
    lotSize = NormalizeDouble(lotSize, 2);
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Actualizar lote específicamente para el botón Market             |
//+------------------------------------------------------------------+
void UpdateMarketButtonLot()
{
    if(slLine == "" || ObjectFind(0, slLine) < 0)
    {
        // Si no hay línea SL, ocultar el botón o mostrar un valor por defecto
        ObjectSetString(0, buttonLotSize, OBJPROP_TEXT, "");
        return;
    }
    
    // Obtener el precio de SL
    double slPrice = GetLinePrice(slLine);
    if(slPrice == 0)
        return;
    
    // Obtener precios actuales del mercado
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double bid = MarketInfo(Symbol(), MODE_BID);
    double marketPrice;
    
    // Determinar si es compra o venta basado en la posición del SL
    if(slPrice < bid) // Compra si SL está por debajo del precio actual
    {
        marketPrice = ask; // Para compras usamos el precio ASK
    }
    else // Venta si SL está por encima
    {
        marketPrice = bid; // Para ventas usamos el precio BID
    }
    
    // Calcular el lote con nuestra nueva función dedicada
    double marketLotSize = CalculateMarketLotSize(marketPrice, slPrice);
    
    // Actualizar el texto del botón
    ObjectSetString(0, buttonLotSize, OBJPROP_TEXT, DoubleToString(marketLotSize, 2) + " lots");
}

//+------------------------------------------------------------------+
//| Colocar orden basada en líneas                                    |
//+------------------------------------------------------------------+
void PlaceOrder(int orderType, double entryPrice, double slPrice, double tpPrice)
{
    // Obtener precios actuales de mercado
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double bid = MarketInfo(Symbol(), MODE_BID);
    double spread = ask - bid;
    double spreadBuffer = spread * SpreadMultiplier;  // Aplicar multiplicador de spread
    
    // Normalizar los precios
    entryPrice = NormalizeDouble(entryPrice, _Digits);
    slPrice = NormalizeDouble(slPrice, _Digits);
    tpPrice = NormalizeDouble(tpPrice, _Digits);
    
    // Ajustar entry según tipo de orden para compensar el spread con buffer
    switch(orderType)
    {
        case OP_BUYSTOP:
        case OP_BUY:
            // Para compras, ajustar al ASK con buffer
            entryPrice = NormalizeDouble(entryPrice + spreadBuffer, _Digits);
            Print("[SPREAD COMPENSATION] Buy Stop/Market: Ajustando entrada de ", entryPrice - spreadBuffer, " a ", entryPrice, " (Spread: ", DoubleToString(spread, _Digits), ", Buffer: ", DoubleToString(spreadBuffer, _Digits), ")");
            break;
            
        case OP_SELLSTOP:
        case OP_SELL:
            // Para ventas, ajustar al BID con buffer
            entryPrice = NormalizeDouble(entryPrice - spreadBuffer, _Digits);
            Print("[SPREAD COMPENSATION] Sell Stop/Market: Ajustando entrada de ", entryPrice + spreadBuffer, " a ", entryPrice, " (Spread: ", DoubleToString(spread, _Digits), ", Buffer: ", DoubleToString(spreadBuffer, _Digits), ")");
            break;
    }
    
    double lotSize = CalculateLotSize(entryPrice, slPrice);
    int ticket = -1;
    
    switch(orderType)
    {
        case OP_BUY:
            ticket = OrderSend(Symbol(), OP_BUY, lotSize, entryPrice, 0, slPrice, tpPrice, "Buy Market", MagicNumber, 0, clrNONE);
            if(ticket == -1)
            {
                int error = GetLastError();
                Print("Error al colocar orden de compra: ", error);
                Alert("Error al colocar orden de compra: ", error);
            }
            else
            {
                Print("Orden de compra colocada correctamente. Ticket: ", ticket);
            }
            break;
            
        case OP_SELL:
            ticket = OrderSend(Symbol(), OP_SELL, lotSize, entryPrice, 0, slPrice, tpPrice, "Sell Market", MagicNumber, 0, clrNONE);
            if(ticket == -1)
            {
                int error = GetLastError();
                Print("Error al colocar orden de venta: ", error);
                Alert("Error al colocar orden de venta: ", error);
            }
            else
            {
                Print("Orden de venta colocada correctamente. Ticket: ", ticket);
            }
            break;
            
        case OP_BUYSTOP:
            ticket = OrderSend(Symbol(), OP_BUYSTOP, lotSize, entryPrice, 0, slPrice, tpPrice, "Buy Stop", MagicNumber, 0, clrNONE);
            if(ticket == -1)
            {
                int error = GetLastError();
                Print("Error al colocar orden de compra stop: ", error);
                Alert("Error al colocar orden de compra stop: ", error);
            }
            else
            {
                Print("Orden de compra stop colocada correctamente. Ticket: ", ticket);
            }
            break;
            
        case OP_SELLSTOP:
            ticket = OrderSend(Symbol(), OP_SELLSTOP, lotSize, entryPrice, 0, slPrice, tpPrice, "Sell Stop", MagicNumber, 0, clrNONE);
            if(ticket == -1)
            {
                int error = GetLastError();
                Print("Error al colocar orden de venta stop: ", error);
                Alert("Error al colocar orden de venta stop: ", error);
            }
            else
            {
                Print("Orden de venta stop colocada correctamente. Ticket: ", ticket);
            }
            break;
            
        case OP_BUYLIMIT:
            ticket = OrderSend(Symbol(), OP_BUYLIMIT, lotSize, entryPrice, 0, slPrice, tpPrice, "Buy Limit", MagicNumber, 0, clrNONE);
            if(ticket == -1)
            {
                int error = GetLastError();
                Print("Error al colocar orden de compra limit: ", error);
                Alert("Error al colocar orden de compra limit: ", error);
            }
            else
            {
                Print("Orden de compra limit colocada correctamente. Ticket: ", ticket);
            }
            break;
            
        case OP_SELLLIMIT:
            ticket = OrderSend(Symbol(), OP_SELLLIMIT, lotSize, entryPrice, 0, slPrice, tpPrice, "Sell Limit", MagicNumber, 0, clrNONE);
            if(ticket == -1)
            {
                int error = GetLastError();
                Print("Error al colocar orden de venta limit: ", error);
                Alert("Error al colocar orden de venta limit: ", error);
            }
            else
            {
                Print("Orden de venta limit colocada correctamente. Ticket: ", ticket);
            }
            break;
    }
}
//+------------------------------------------------------------------+
//| Crear una línea de trading                                        |
//+------------------------------------------------------------------+
bool CreateTradeLine(string name, datetime time1, double price1, color lineColor)
{
    if(!ObjectCreate(name, OBJ_HLINE, 0, time1, price1))
        return false;
        
    ObjectSet(name, OBJPROP_COLOR, lineColor);
    ObjectSet(name, OBJPROP_WIDTH, 1);
    ObjectSet(name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSet(name, OBJPROP_SELECTABLE, true);
    ObjectSet(name, OBJPROP_SELECTED, true);
    ObjectSet(name, OBJPROP_BACK, false);
    ObjectSet(name, OBJPROP_RAY, true);
    ObjectSet(name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    ObjectSet(name, OBJPROP_HIDDEN, false);
    ObjectSet(name, OBJPROP_ZORDER, 0);
    ObjectSet(name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSet(name, OBJPROP_READONLY, true);
    
    
    
    return true;
}

//+------------------------------------------------------------------+
//| Actualizar la posición de una línea                               |
//+------------------------------------------------------------------+
void UpdateTradeLine(string name, datetime time, double price)
{
    if(ObjectFind(0, name) >= 0)
    {
        ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
    }
}

//+------------------------------------------------------------------+
//| Obtener el precio de una línea                                    |
//+------------------------------------------------------------------+
double GetLinePrice(string name)
{
    if(ObjectFind(0, name) >= 0)
        return ObjectGetDouble(0, name, OBJPROP_PRICE);
    return 0;
}


//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
    // Verificar si hay órdenes pendientes
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MagicNumber)
        {
            // Manejar Buy Stop
            if(OrderType() == OP_BUYSTOP && OrderSymbol() == Symbol())
            {
                double currentPrice = MarketInfo(Symbol(), MODE_BID);
                double orderSL = OrderStopLoss();
                double orderEntry = OrderOpenPrice();
                
                // Si el precio actual está en o por debajo del SL
                if(currentPrice <= orderSL)
                {
                    // Cancelar la orden pendiente
                    if(OrderDelete(OrderTicket()))
                    {
                        Print("Orden Buy Stop cancelada porque el precio alcanzó el nivel de SL: ", orderSL);
                        // Limpiar las líneas y objetos visuales
                        DeleteLinesAndArrows();
                    }
                    else
                    {
                        Print("Error al cancelar la orden: ", GetLastError());
                    }
                }
            }
            // Manejar Sell Stop
            else if(OrderType() == OP_SELLSTOP && OrderSymbol() == Symbol())
            {
                double currentPrice = MarketInfo(Symbol(), MODE_ASK);
                double orderSL = OrderStopLoss();
                double orderEntry = OrderOpenPrice();
                
                // Si el precio actual está en o por encima del SL
                if(currentPrice >= orderSL)
                {
                    // Cancelar la orden pendiente
                    if(OrderDelete(OrderTicket()))
                    {
                        Print("Orden Sell Stop cancelada porque el precio alcanzó el nivel de SL: ", orderSL);
                        // Limpiar las líneas y objetos visuales
                        DeleteLinesAndArrows();
                    }
                    else
                    {
                        Print("Error al cancelar la orden: ", GetLastError());
                    }
                }
            }
            // Manejar Buy Limit
            else if(OrderType() == OP_BUYLIMIT && OrderSymbol() == Symbol())
            {
                double currentPrice = MarketInfo(Symbol(), MODE_BID);
                double orderSL = OrderStopLoss();
                double orderEntry = OrderOpenPrice();
                
                // Si el precio actual está en o por debajo del SL
                if(currentPrice <= orderSL)
                {
                    // Cancelar la orden pendiente
                    if(OrderDelete(OrderTicket()))
                    {
                        Print("Orden Buy Limit cancelada porque el precio alcanzó el nivel de SL: ", orderSL);
                        // Limpiar las líneas y objetos visuales
                        DeleteLinesAndArrows();
                    }
                    else
                    {
                        Print("Error al cancelar la orden: ", GetLastError());
                    }
                }
            }
            // Manejar Sell Limit
            else if(OrderType() == OP_SELLLIMIT && OrderSymbol() == Symbol())
            {
                double currentPrice = MarketInfo(Symbol(), MODE_ASK);
                double orderSL = OrderStopLoss();
                double orderEntry = OrderOpenPrice();
                
                // Si el precio actual está en o por encima del SL
                if(currentPrice >= orderSL)
                {
                    // Cancelar la orden pendiente
                    if(OrderDelete(OrderTicket()))
                    {
                        Print("Orden Sell Limit cancelada porque el precio alcanzó el nivel de SL: ", orderSL);
                        // Limpiar las líneas y objetos visuales
                        DeleteLinesAndArrows();
                    }
                    else
                    {
                        Print("Error al cancelar la orden: ", GetLastError());
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Guardar estado global                                             |
//+------------------------------------------------------------------+
// Función para guardar el estado global
void SaveGlobalState()
{
   // Print("Guardando estado global...");
    
    // Crear el prefijo específico del símbolo
    string symbolPrefix = GLOBAL_VAR_PREFIX + Symbol() + "_";
    
    // Guardar el valor del riesgo
    GlobalVariableSet(symbolPrefix + "RiskPercent", currentRiskPercent);
  //  Print("Guardado valor de riesgo: ", currentRiskPercent);
    
    // Guardar precios
    if(entryLine != "")
    {
        double entryPrice = GetLinePrice(entryLine);
        GlobalVariableSet(symbolPrefix + "EntryPrice", entryPrice);
     //   Print("Guardado precio de entrada: ", entryPrice);
    }
    
    if(slLine != "")
    {
        double slPrice = GetLinePrice(slLine);
        GlobalVariableSet(symbolPrefix + "SLPrice", slPrice);
      //  Print("Guardado precio de SL: ", slPrice);
    }
    
    if(tpLine != "")
    {
        double tpPrice = GetLinePrice(tpLine);
        GlobalVariableSet(symbolPrefix + "TPPrice", tpPrice);
     //   Print("Guardado precio de TP: ", tpPrice);
    }
        
    // Guardar estados de botones
    GlobalVariableSet(symbolPrefix + "SLActive", slActive ? 1 : 0);
    GlobalVariableSet(symbolPrefix + "TPActive", tpActive ? 1 : 0);
    
    // Guardar valores de los cuadros de texto
    string lotSizeText = ObjectGetString(0, buttonLotSize, OBJPROP_TEXT);
    if(lotSizeText != "")
        GlobalVariableSet(symbolPrefix + "LotSize", StringToDouble(lotSizeText));
    
    // Guardar valores de los botones de preview (fila 3)
    string slPreviewText = ObjectGetString(0, buttonSLPreview, OBJPROP_TEXT);
    if(slPreviewText != "")
        GlobalVariableSet(symbolPrefix + "SLPreview", StringToDouble(slPreviewText));
        
    string tpPreviewText = ObjectGetString(0, buttonTPPreview, OBJPROP_TEXT);
    if(tpPreviewText != "")
        GlobalVariableSet(symbolPrefix + "TPPreview", StringToDouble(tpPreviewText));
        
    string entryPreviewText = ObjectGetString(0, buttonEntryPreview, OBJPROP_TEXT);
    if(entryPreviewText != "")
        GlobalVariableSet(symbolPrefix + "EntryPreview", StringToDouble(entryPreviewText));
        
    // Guardar el estado del botón Apply
    color applyColor = (color)ObjectGetInteger(0, buttonApply, OBJPROP_BGCOLOR);
    GlobalVariableSet(symbolPrefix + "ApplyColor", applyColor);
    
    // Guardar el estado del botón Sync
    color syncColor = (color)ObjectGetInteger(0, buttonSync, OBJPROP_BGCOLOR);
    GlobalVariableSet(symbolPrefix + "SyncColor", syncColor);
    
    // Guardar precios y colores de las líneas
    if(entryLine != "")
    {
        GlobalVariableSet(symbolPrefix + "EntryPrice", GetLinePrice(entryLine));
        GlobalVariableSet(symbolPrefix + "EntryColor", ObjectGet(entryLine, OBJPROP_COLOR));
    }
    
    if(slLine != "")
    {
        GlobalVariableSet(symbolPrefix + "SLPrice", GetLinePrice(slLine));
        GlobalVariableSet(symbolPrefix + "SLColor", ObjectGet(slLine, OBJPROP_COLOR));
    }
    
    if(tpLine != "")
    {
        GlobalVariableSet(symbolPrefix + "TPPrice", GetLinePrice(tpLine));
        GlobalVariableSet(symbolPrefix + "TPColor", ObjectGet(tpLine, OBJPROP_COLOR));
    }    
                
 //   Print("Estado global guardado completamente");
    
}

//+------------------------------------------------------------------+
//| Restaurar estado global                                           |
//+------------------------------------------------------------------+
void RestoreGlobalState()
{
 //   Print("Restaurando estado global...");
    datetime time = TimeCurrent();
    
    // Crear el prefijo específico del símbolo
    string symbolPrefix = GLOBAL_VAR_PREFIX + Symbol() + "_";
    
    // Restaurar el valor del riesgo (a la variable interna)
    if(GlobalVariableCheck(symbolPrefix + "RiskPercent"))
    {
        currentRiskPercent = GlobalVariableGet(symbolPrefix + "RiskPercent");
        ObjectSetString(0, buttonRisk, OBJPROP_TEXT, DoubleToString(currentRiskPercent, 2) + "%");
 //       Print("Valor de riesgo restaurado: ", currentRiskPercent);
    }

    // Primero eliminar las líneas existentes para evitar duplicados
    ObjectDelete(0, entryLine);
    ObjectDelete(0, slLine);
    ObjectDelete(0, tpLine);
     
    // Restaurar líneas y precios
    if(GlobalVariableCheck(symbolPrefix + "EntryPrice"))
    {
        double price = GlobalVariableGet(symbolPrefix + "EntryPrice");
        if(price != 0)
        {
            if(ObjectFind(0, entryLine) >= 0)
                ObjectDelete(0, entryLine);
                
            ObjectCreate(0, entryLine, OBJ_HLINE, 0, time, price);
            ObjectSetInteger(0, entryLine, OBJPROP_COLOR, LineColorBuy);
            ObjectSetInteger(0, entryLine, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, entryLine, OBJPROP_STYLE, STYLE_SOLID);
            Print("Línea de entrada restaurada a precio: ", price);
        }
    }
    
    if(GlobalVariableCheck(symbolPrefix + "SLPrice"))
    {
        double price = GlobalVariableGet(symbolPrefix + "SLPrice");
        if(price != 0)
        {
            if(ObjectFind(0, slLine) >= 0)
                ObjectDelete(0, slLine);
                
            ObjectCreate(0, slLine, OBJ_HLINE, 0, time, price);
            ObjectSetInteger(0, slLine, OBJPROP_COLOR, LineColorSL);
            ObjectSetInteger(0, slLine, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, slLine, OBJPROP_STYLE, STYLE_SOLID);
            Print("Línea de SL restaurada a precio: ", price);
        }
    }
    
    if(GlobalVariableCheck(symbolPrefix + "TPPrice"))
    {
        double price = GlobalVariableGet(symbolPrefix + "TPPrice");
        if(price != 0)
        {
            if(ObjectFind(0, tpLine) >= 0)
                ObjectDelete(0, tpLine);
                
            ObjectCreate(0, tpLine, OBJ_HLINE, 0, time, price);
            ObjectSetInteger(0, tpLine, OBJPROP_COLOR, LineColorTP);
            ObjectSetInteger(0, tpLine, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, tpLine, OBJPROP_STYLE, STYLE_SOLID);
            Print("Línea de TP restaurada a precio: ", price);
        }
    }
        
    // Restaurar estados de botones
    if(GlobalVariableCheck(symbolPrefix + "SLActive"))
    {
        slActive = GlobalVariableGet(symbolPrefix + "SLActive") > 0;
    //    Print("Estado de SL restaurado: ", slActive);
        if(slActive)
        {
            ObjectSetInteger(0, buttonSL, OBJPROP_BGCOLOR, clrRed);
            ObjectSetInteger(0, buttonSL, OBJPROP_COLOR, clrWhite);
        }
    }
    
    if(GlobalVariableCheck(symbolPrefix + "TPActive"))
    {
        tpActive = GlobalVariableGet(symbolPrefix + "TPActive") > 0;
      //  Print("Estado de TP restaurado: ", tpActive);
        if(tpActive)
        {
            ObjectSetInteger(0, buttonTP, OBJPROP_BGCOLOR, clrGreen);
            ObjectSetInteger(0, buttonTP, OBJPROP_COLOR, clrWhite);
        }
    }
        

    // Restaurar valores de los cuadros de texto
    if(GlobalVariableCheck(symbolPrefix + "LotSize"))
    {
       // En lugar de usar el valor almacenado, calcular con precio de mercado
       if(slLine != "" && ObjectFind(0, slLine) >= 0)
       {
          double slPrice = GetLinePrice(slLine);
          double lastTick_ask = MarketInfo(Symbol(), MODE_ASK);
          double lastTick_bid = MarketInfo(Symbol(), MODE_BID);
          double marketPrice;
        
          // Determinar si es compra o venta basado en la posición del SL
          if(slPrice < lastTick_bid)  // Compra
          {
                marketPrice = lastTick_ask;
          }
          else  // Venta
          {
                marketPrice = lastTick_bid;
          }
        
          // Calcular lotaje usando el precio actual del mercado
          double marketLotSize = CalculateMarketLotSize(marketPrice, slPrice);
          ObjectSetString(0, buttonLotSize, OBJPROP_TEXT, DoubleToString(marketLotSize, 2) + " lots");
       }
    }    
    // Restaurar valores de los botones de preview (fila 3)
    if(GlobalVariableCheck(symbolPrefix + "SLPreview"))
    {
        double slPreview = GlobalVariableGet(symbolPrefix + "SLPreview");
        ObjectSetString(0, buttonSLPreview, OBJPROP_TEXT, DoubleToString(slPreview, _Digits));
    }
    
    if(GlobalVariableCheck(symbolPrefix + "TPPreview"))
    {
        double tpPreview = GlobalVariableGet(symbolPrefix + "TPPreview");
        ObjectSetString(0, buttonTPPreview, OBJPROP_TEXT, DoubleToString(tpPreview, _Digits));
    }
    
    if(GlobalVariableCheck(symbolPrefix + "EntryPreview"))
    {
        double entryPreview = GlobalVariableGet(symbolPrefix + "EntryPreview");
        ObjectSetString(0, buttonEntryPreview, OBJPROP_TEXT, DoubleToString(entryPreview, _Digits));
    }
    
    // Restaurar el estado del botón Apply
    if(GlobalVariableCheck(symbolPrefix + "ApplyColor"))
    {
        color applyColor = (color)GlobalVariableGet(symbolPrefix + "ApplyColor");
        ObjectSetInteger(0, buttonApply, OBJPROP_BGCOLOR, applyColor);
        ObjectSetInteger(0, buttonApply, OBJPROP_COLOR, applyColor == clrBlue ? clrWhite : clrBlack);
    }
        
    // Restaurar el estado del botón Sync
    if(GlobalVariableCheck(symbolPrefix + "SyncColor"))
    {
        color syncColor = (color)GlobalVariableGet(symbolPrefix + "SyncColor");
        ObjectSetInteger(0, buttonSync, OBJPROP_BGCOLOR, syncColor);
        ObjectSetInteger(0, buttonSync, OBJPROP_COLOR, syncColor == clrLightGreen ? clrBlack : clrBlack);
    }
        
    UpdatePriceLabels();
    ChartRedraw();
 //   Print("Estado global restaurado completamente");
}

//+------------------------------------------------------------------+
//| Sincronismo entre graficos                                        |
//+------------------------------------------------------------------+
void SyncChartsLines()
{
    string currentSymbol = Symbol();
    long chartID = ChartFirst();
    
    while(chartID >= 0)
    {
        if(ChartSymbol(chartID) == currentSymbol && chartID != ChartID())
        {
            // Sincronizar línea de entrada
            if(ObjectFind(0, entryLine) >= 0)
            {
                double price = ObjectGetDouble(0, entryLine, OBJPROP_PRICE);
                if(ObjectFind(chartID, entryLine) >= 0)
                    ObjectDelete(chartID, entryLine);
                    
                ObjectCreate(chartID, entryLine, OBJ_HLINE, 0, TimeCurrent(), price);
                ObjectSetInteger(chartID, entryLine, OBJPROP_COLOR, LineColorBuy);
                ObjectSetInteger(chartID, entryLine, OBJPROP_WIDTH, 1);
                ObjectSetInteger(chartID, entryLine, OBJPROP_STYLE, STYLE_SOLID);
            }
            
            // Sincronizar línea de SL
            if(ObjectFind(0, slLine) >= 0)
            {
                double price = ObjectGetDouble(0, slLine, OBJPROP_PRICE);
                if(ObjectFind(chartID, slLine) >= 0)
                    ObjectDelete(chartID, slLine);
                    
                ObjectCreate(chartID, slLine, OBJ_HLINE, 0, TimeCurrent(), price);
                ObjectSetInteger(chartID, slLine, OBJPROP_COLOR, LineColorSL);
                ObjectSetInteger(chartID, slLine, OBJPROP_WIDTH, 1);
                ObjectSetInteger(chartID, slLine, OBJPROP_STYLE, STYLE_SOLID);
            }
            
            // Sincronizar línea de TP
            if(ObjectFind(0, tpLine) >= 0)
            {
                double price = ObjectGetDouble(0, tpLine, OBJPROP_PRICE);
                if(ObjectFind(chartID, tpLine) >= 0)
                    ObjectDelete(chartID, tpLine);
                    
                ObjectCreate(chartID, tpLine, OBJ_HLINE, 0, TimeCurrent(), price);
                ObjectSetInteger(chartID, tpLine, OBJPROP_COLOR, LineColorTP);
                ObjectSetInteger(chartID, tpLine, OBJPROP_WIDTH, 1);
                ObjectSetInteger(chartID, tpLine, OBJPROP_STYLE, STYLE_SOLID);
            }
            
            ChartRedraw(chartID);
        }
        chartID = ChartNext(chartID);
    }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Print("Event ID: ", id, " sparam: ", sparam); // Debug para ver todos los eventos
    
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(sparam == buttonSL)
        {
            slActive = !slActive;
            
            if(slActive)
            {
                // Cambiar color del botón a verde cuando está activo
                ObjectSetInteger(0, buttonSL, OBJPROP_BGCOLOR, clrRed);
                ObjectSetInteger(0, buttonSL, OBJPROP_COLOR, clrWhite);
                ObjectSetInteger(0, buttonSL, OBJPROP_STATE, false);
                
                // Obtener el precio actual
                double lastTick_ask = MarketInfo(Symbol(), MODE_ASK);  // Equivalente a lastTick.ask
                
                // Memorizar el precio actual
                memorizedPrice = lastTick_ask;
                
                // Calcular el precio del SL (20 pips por debajo del precio actual)
                double slPrice = lastTick_ask - DefaultPipDistance * _Point;
                
                // Mostrar el precio del SL en el botón de preview (fila 3, columna 2)
                ObjectSetString(0, buttonSLPreview, OBJPROP_TEXT, DoubleToString(slPrice, _Digits));
                
                // Mostrar el precio memorizado en el botón de entrada (fila 3, columna 4)
                ObjectSetString(0, buttonEntryPreview, OBJPROP_TEXT, DoubleToString(memorizedPrice, _Digits));
                
                // Guardar valores en variables globales para sincronización
                GlobalVariableSet(GLOBAL_VAR_PREFIX + Symbol() + "_SLPreview", slPrice);
                GlobalVariableSet(GLOBAL_VAR_PREFIX + Symbol() + "_EntryPreview", memorizedPrice);
                
                // Limpiar mensaje de TP
                ObjectSetString(0, labelTPMessage, OBJPROP_TEXT, "");
                ObjectSetInteger(0, labelTPMessage, OBJPROP_HIDDEN, true); // Ocultar cuando no hay mensaje
            }
            else
            {
                // Restaurar color original del botón cuando está inactivo
                ObjectSetInteger(0, buttonSL, OBJPROP_BGCOLOR, clrLightGray);
                ObjectSetInteger(0, buttonSL, OBJPROP_COLOR, clrBlack);
                
                // Desactivar también el botón TP si está activo
                if(tpActive)
                {
                    tpActive = false;
                    ObjectSetInteger(0, buttonTP, OBJPROP_BGCOLOR, clrLightGray);
                    ObjectSetInteger(0, buttonTP, OBJPROP_COLOR, clrBlack);
                    ObjectSetString(0, buttonTPPreview, OBJPROP_TEXT, "");
                    GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_TPPreview");
                }
                
                // Limpiar los textos de los botones de preview y sus variables globales
                ObjectSetString(0, buttonSLPreview, OBJPROP_TEXT, "");
                ObjectSetString(0, buttonEntryPreview, OBJPROP_TEXT, "");
                GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_SLPreview");
                GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_EntryPreview");
                
                ObjectSetString(0, labelTPMessage, OBJPROP_TEXT, "");
                ObjectSetInteger(0, labelTPMessage, OBJPROP_HIDDEN, true); // Ocultar cuando no hay mensaje
                
                // Resetear el precio memorizado
                memorizedPrice = 0;
            }
            
            // Guardar el estado del botón SL
            GlobalVariableSet(GLOBAL_VAR_PREFIX + Symbol() + "_SLActive", slActive ? 1 : 0);
            
            ChartRedraw();
            return;
        }
        else if(sparam == buttonTP)
        {
            ObjectSetInteger(0, buttonTP, OBJPROP_STATE, false);
            
            // Verificar si SL está activado primero
            if(!slActive)
            {
                // Recrear el objeto cada vez
                if(ObjectFind(0, labelTPMessage) >= 0)
                    ObjectDelete(0, labelTPMessage);
                    
                ObjectCreate(0, labelTPMessage, OBJ_EDIT, 0, 0, 0);
                ObjectSetInteger(0, labelTPMessage, OBJPROP_XDISTANCE, xStart + (buttonWidth + spacing) * 2);
                ObjectSetInteger(0, labelTPMessage, OBJPROP_YDISTANCE, yPos3 + buttonHeight + 2);
                ObjectSetInteger(0, labelTPMessage, OBJPROP_XSIZE, buttonWidth * 3);
                ObjectSetInteger(0, labelTPMessage, OBJPROP_YSIZE, 20);
                ObjectSetInteger(0, labelTPMessage, OBJPROP_COLOR, clrRed);
                ObjectSetInteger(0, labelTPMessage, OBJPROP_BGCOLOR, clrWhite);
                ObjectSetInteger(0, labelTPMessage, OBJPROP_BORDER_COLOR, clrWhite);
                ObjectSetInteger(0, labelTPMessage, OBJPROP_FONTSIZE, 7);
                ObjectSetInteger(0, labelTPMessage, OBJPROP_READONLY, true);
                ObjectSetInteger(0, labelTPMessage, OBJPROP_SELECTABLE, false);
                ObjectSetString(0, labelTPMessage, OBJPROP_TEXT, "Debes activar primero StopLoss");
                ObjectSetInteger(0, labelTPMessage, OBJPROP_HIDDEN, false);
                ChartRedraw();
                return;
            }
            
            // Si llegamos aquí, SL está activo, asi que ocultamos el mensaje
            ObjectDelete(0, labelTPMessage);
            ChartRedraw();
            
            tpActive = !tpActive;
            
            if(tpActive)
            {
                // Cambiar color del botón a verde cuando está activo
                ObjectSetInteger(0, buttonTP, OBJPROP_BGCOLOR, clrGreen);
                ObjectSetInteger(0, buttonTP, OBJPROP_COLOR, clrWhite);
                
                // Guardar estado del botón TP
                GlobalVariableSet(GLOBAL_VAR_PREFIX + Symbol() + "_TPActive", 1);
                
                // Verificar que tenemos un precio memorizado válido
                if(memorizedPrice > 0)
                {
                    // Calcular el precio del TP (20 pips por encima del precio memorizado)
                    double tpPrice = memorizedPrice + DefaultPipDistance * _Point;
                    
                    // Mostrar el precio del TP en el botón de preview (fila 3, columna 3)
                    ObjectSetString(0, buttonTPPreview, OBJPROP_TEXT, DoubleToString(tpPrice, _Digits));
                    
                    // Guardar valor en variable global para sincronización
                    GlobalVariableSet(GLOBAL_VAR_PREFIX + Symbol() + "_TPPreview", tpPrice);
                    
                    // Limpiar mensaje de error
                    ObjectSetString(0, labelTPMessage, OBJPROP_TEXT, "");
                    ObjectSetInteger(0, labelTPMessage, OBJPROP_HIDDEN, true); // Ocultar cuando no hay mensaje
                }
            }
            else
            {
                // Restaurar color original del botón cuando está inactivo
                ObjectSetInteger(0, buttonTP, OBJPROP_BGCOLOR, clrLightGray);
                ObjectSetInteger(0, buttonTP, OBJPROP_COLOR, clrBlack);
                
                // Limpiar el texto del botón de preview y su variable global
                ObjectSetString(0, buttonTPPreview, OBJPROP_TEXT, "");
                GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_TPPreview");
                
                // Guardar estado del botón TP
                GlobalVariableSet(GLOBAL_VAR_PREFIX + Symbol() + "_TPActive", 0);
            }
            
            ChartRedraw();
            return;
        }

        else if(sparam == buttonApply)
        {
            // Cambiar color del botón a azul cuando está activo
            ObjectSetInteger(0, buttonApply, OBJPROP_BGCOLOR, clrBlue);
            ObjectSetInteger(0, buttonApply, OBJPROP_COLOR, clrWhite);  
            ObjectSetInteger(0, buttonApply, OBJPROP_STATE, false);
            
            // Desactivar botón Sincro
            ObjectSetInteger(0, buttonSync, OBJPROP_BGCOLOR, clrLightGreen);
            ObjectSetInteger(0, buttonSync, OBJPROP_COLOR, clrBlack);
            ObjectSetInteger(0, buttonSync, OBJPROP_STATE, false);
            
            // Obtener los valores de los botones de preview
            string slText = ObjectGetString(0, buttonSLPreview, OBJPROP_TEXT);
            string tpText = ObjectGetString(0, buttonTPPreview, OBJPROP_TEXT);
            string entryText = ObjectGetString(0, buttonEntryPreview, OBJPROP_TEXT);
            
            // Convertir los textos a precios
            double slPrice = StringToDouble(slText);
            double tpPrice = StringToDouble(tpText);
            double entryPrice = StringToDouble(entryText);
            
            // Crear o actualizar las líneas según los valores
            if(slPrice > 0)
            {
                if(ObjectFind(0, slLine) >= 0)
                    ObjectDelete(0, slLine);
                    
                slLine = GetUniqueObjectName("Trade_SL");
                CreateTradeLine(slLine, TimeCurrent(), slPrice, LineColorSL);
                ObjectSetString(0, buttonSLLevel, OBJPROP_TEXT, DoubleToString(slPrice, _Digits));
            }
              
            if(tpPrice > 0)
            {
                if(ObjectFind(0, tpLine) >= 0)
                    ObjectDelete(0, tpLine);
                    
                tpLine = GetUniqueObjectName("Trade_TP");
                CreateTradeLine(tpLine, TimeCurrent(), tpPrice, LineColorTP);
                ObjectSetString(0, buttonTPLevel, OBJPROP_TEXT, DoubleToString(tpPrice, _Digits));
            }
    
            if(entryPrice > 0)
            {
                if(ObjectFind(0, entryLine) >= 0)
                    ObjectDelete(0, entryLine);
                    
                entryLine = GetUniqueObjectName("Trade_Entry");
                CreateTradeLine(entryLine, TimeCurrent(), entryPrice, LineColorBuy);
                ObjectSetString(0, buttonEntryLevel, OBJPROP_TEXT, DoubleToString(entryPrice, _Digits));
            }
       
            // Actualizar etiquetas
            UpdatePriceLabels();
            
            // Sincronizar líneas con otros gráficos
            SyncChartsLines();
    
            ChartRedraw();
            return;
        }
        else if(sparam == buttonExecute)
        {
            ObjectSetInteger(0, buttonExecute, OBJPROP_BGCOLOR, clrLightGray);
            ObjectSetInteger(0, buttonExecute, OBJPROP_COLOR, clrBlack);
            ObjectSetInteger(0, buttonExecute, OBJPROP_STATE, false);
            
            if(entryLine == "")
            {
                Print("Error: Establezca primero los niveles de trading");
                return;
            }

            double entryPrice = GetLinePrice(entryLine);
            double slPrice = GetLinePrice(slLine);
            double tpPrice = GetLinePrice(tpLine);
            
            // Verificar que tenemos los precios necesarios
            if(entryPrice == 0)
            {
                Print("Error: Precio de entrada no válido");
                return;
            }

            if(slPrice == 0)
            {
                Print("Error: Stop Loss no establecido");
                return;
            }

            if(tpPrice == 0)
            {
                Print("Error: Take Profit no establecido");
                return;
            }

            // Obtener precio actual
            double ask = MarketInfo(Symbol(), MODE_ASK);
            double bid = MarketInfo(Symbol(), MODE_BID);
            
            // Determinar tipo de orden basado en el precio de entrada y SL
            if(entryPrice > ask)  // Precio de entrada por encima del mercado
            {
                if(slPrice > entryPrice)  // SL por encima del precio de entrada
                {
                    Print("Colocando Sell Limit en ", entryPrice);
                    PlaceOrder(OP_SELLLIMIT, entryPrice, slPrice, tpPrice);
                }
                else  // SL por debajo del precio de entrada
                {
                    Print("Colocando Buy Stop en ", entryPrice);
                    PlaceOrder(OP_BUYSTOP, entryPrice, slPrice, tpPrice);
                }
            }
            else if(entryPrice < bid)  // Precio de entrada por debajo del mercado
            {
                if(slPrice > entryPrice)  // SL por encima del precio de entrada
                {
                    Print("Colocando Sell Stop en ", entryPrice);
                    PlaceOrder(OP_SELLSTOP, entryPrice, slPrice, tpPrice);
                }
                else  // SL por debajo del precio de entrada
                {
                    Print("Colocando Buy Limit en ", entryPrice);
                    PlaceOrder(OP_BUYLIMIT, entryPrice, slPrice, tpPrice);
                }
            }

            // Limpiar todos los datos, líneas y botones
            LimpiezaDatosLineas();
        }
        else if(sparam == buttonCancel)
        {
            ObjectSetInteger(0, buttonCancel, OBJPROP_BGCOLOR, clrLightGray);
            ObjectSetInteger(0, buttonCancel, OBJPROP_COLOR, clrBlack);
            ObjectSetInteger(0, buttonCancel, OBJPROP_STATE, false);
            
            // Limpiar todos los datos, líneas y botones
            LimpiezaDatosLineas();
            
            // Ocultar mensaje de TP si está visible
            if(ObjectFind(0, labelTPMessage) >= 0)
            {
                ObjectDelete(0, labelTPMessage);
            }
            return;
        }

        else if(sparam == buttonRisk)
        {
            ObjectSetInteger(0, buttonRisk, OBJPROP_STATE, false);
            // Crear campo de entrada justo debajo del botón de riesgo
            string inputName = "RiskInput";
            if(ObjectFind(0, inputName) >= 0)
                ObjectDelete(0, inputName);
            
            // Obtener la posición del botón de riesgo
            int riskButtonX = (int)ObjectGetInteger(0, buttonRisk, OBJPROP_XDISTANCE);
            int riskButtonY = (int)ObjectGetInteger(0, buttonRisk, OBJPROP_YDISTANCE);
            int riskButtonHeight = (int)ObjectGetInteger(0, buttonRisk, OBJPROP_YSIZE);
            int riskButtonWidth = (int)ObjectGetInteger(0, buttonRisk, OBJPROP_XSIZE);
            
            ObjectCreate(0, inputName, OBJ_EDIT, 0, 0, 0);
            ObjectSetInteger(0, inputName, OBJPROP_XDISTANCE, riskButtonX);  // Misma X que el botón de riesgo
            ObjectSetInteger(0, inputName, OBJPROP_YDISTANCE, riskButtonY + riskButtonHeight + 2);  // Y del botón + altura + 2 pixels
            ObjectSetInteger(0, inputName, OBJPROP_XSIZE, riskButtonWidth);  // Mismo ancho que el botón
            ObjectSetInteger(0, inputName, OBJPROP_YSIZE, riskButtonHeight);  // Mismo alto que el botón
            ObjectSetString(0, inputName, OBJPROP_TEXT, DoubleToString(currentRiskPercent, 3));
            ObjectSetInteger(0, inputName, OBJPROP_COLOR, clrBlack);
            ObjectSetInteger(0, inputName, OBJPROP_BGCOLOR, clrWhite);
            ObjectSetInteger(0, inputName, OBJPROP_ALIGN, ALIGN_CENTER);
            ObjectSetInteger(0, inputName, OBJPROP_READONLY, false);
            ObjectSetInteger(0, inputName, OBJPROP_FONTSIZE, 10);
            ObjectSetString(0, inputName, OBJPROP_FONT, "Arial");
        }
         else if(sparam == buttonMarket)
         {
            ObjectSetInteger(0, buttonMarket, OBJPROP_STATE, false);
    
            double lastTick_ask = MarketInfo(Symbol(), MODE_ASK);  // Equivalente a lastTick.ask
            double lastTick_bid = MarketInfo(Symbol(), MODE_BID);  // Equivalente a lastTick.bid
            double marketPrice = lastTick_ask;  // Para compra
            double slPrice = GetLinePrice(slLine);
            double tpPrice = GetLinePrice(tpLine);
    
            // Determinar si es compra o venta basado en la posición del SL
            if(slPrice != 0)
            {
               if(slPrice < marketPrice)
               {
                     int ticket = OrderSend(Symbol(), OP_BUY, CalculateMarketLotSize(marketPrice, slPrice), marketPrice, 3, slPrice, tpPrice, "Buy Market", MagicNumber, 0, clrBlue);
                     if(ticket == -1)
                     {
                        int error = GetLastError();
                        Print("Error al colocar orden de compra a mercado: ", error);
                        Alert("Error al colocar orden de compra: ", error);
                     }
                     else
                     {
                        Print("Orden de compra colocada correctamente. Ticket: ", ticket);
                     }
               }
               else
               {
                     marketPrice = lastTick_bid;  // Para venta
                     int ticket = OrderSend(Symbol(), OP_SELL, CalculateMarketLotSize(marketPrice, slPrice), marketPrice, 3, slPrice, tpPrice, "Sell Market", MagicNumber, 0, clrRed);
                     if(ticket == -1)
                     {
                        int error = GetLastError();
                        Print("Error al colocar orden de venta a mercado: ", error);
                        Alert("Error al colocar orden de venta: ", error);
                     }
                     else
                     {
                        Print("Orden de venta colocada correctamente. Ticket: ", ticket);
                     }
               }
               
               
               
               // Limpiar todos los datos, líneas y botones
               LimpiezaDatosLineas();

               
               
               
               
               
               
            }
         }        
        
        else if(sparam == buttonSync)
        {
            ObjectSetInteger(0, buttonSync, OBJPROP_BGCOLOR, clrLightGreen);
            ObjectSetInteger(0, buttonSync, OBJPROP_COLOR, clrBlack);
            ObjectSetInteger(0, buttonSync, OBJPROP_STATE, false);
            
            // Obtener los precios de las líneas existentes
            double slPrice = 0, tpPrice = 0, entryPrice = 0;
            
            // Obtener precio de la línea SL si existe
            if(ObjectFind(0, slLine) >= 0)
            {
                slPrice = ObjectGetDouble(0, slLine, OBJPROP_PRICE);
                ObjectSetString(0, buttonSLPreview, OBJPROP_TEXT, DoubleToString(slPrice, _Digits));
                Print("SL Price encontrado: ", slPrice);
            }
            else
            {
                Print("Línea SL no encontrada");
            }
            
            Print("Buscando línea TP..."); // Debug
            // Obtener precio de la línea TP si existe
            if(ObjectFind(0, tpLine) >= 0)
            {
                tpPrice = ObjectGetDouble(0, tpLine, OBJPROP_PRICE);
                ObjectSetString(0, buttonTPPreview, OBJPROP_TEXT, DoubleToString(tpPrice, _Digits));
                Print("TP Price encontrado: ", tpPrice);
            }
            else
            {
                Print("Línea TP no encontrada");
            }
            
            Print("Buscando línea Entry..."); // Debug
            // Obtener precio de la línea Entry si existe
            if(ObjectFind(0, entryLine) >= 0)
            {
                entryPrice = ObjectGetDouble(0, entryLine, OBJPROP_PRICE);
                ObjectSetString(0, buttonEntryPreview, OBJPROP_TEXT, DoubleToString(entryPrice, _Digits));
                Print("Entry Price encontrado: ", entryPrice);
            }
            else
            {
                Print("Línea Entry no encontrada");
            }
            ChartRedraw();
            return;
        }
    }
    
    // Manejar el movimiento de las líneas
   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      // Actualizar etiquetas cuando se mueven las líneas
      if(sparam == entryLine || sparam == slLine || sparam == tpLine)
      {
         ObjectSetInteger(0, buttonSync, OBJPROP_BGCOLOR, clrYellow);
         ObjectSetInteger(0, buttonSync, OBJPROP_COLOR, clrBlack);
         ObjectSetInteger(0, buttonSync, OBJPROP_STATE, false);

         // Guardar el nuevo precio de entrada cuando se mueve la línea
         if(sparam == entryLine)
         {
            storedEntryPrice = ObjectGetDouble(0, entryLine, OBJPROP_PRICE);
            if(storedEntryPrice != 0)
            {
               ObjectSetString(0, buttonEntryLevel, OBJPROP_TEXT, DoubleToString(storedEntryPrice, _Digits));
            }
         }
        
         // Guardar el nuevo precio de SL cuando se mueve la línea
         if(sparam == slLine)
         {
            storedSLPrice = ObjectGetDouble(0, slLine, OBJPROP_PRICE);
            if(storedSLPrice != 0)
            {
               ObjectSetString(0, buttonSLLevel, OBJPROP_TEXT, DoubleToString(storedSLPrice, _Digits));
            }
         }
        
         // Guardar el nuevo precio de TP cuando se mueve la línea
         if(sparam == tpLine)
         {
            storedTPPrice = ObjectGetDouble(0, tpLine, OBJPROP_PRICE);
            if(storedTPPrice != 0)
            {
               ObjectSetString(0, buttonTPLevel, OBJPROP_TEXT, DoubleToString(storedTPPrice, _Digits));
            }
         }
         
         // Sincronizar las líneas en todos los gráficos inmediatamente
         SyncChartsLines();
         SaveGlobalState();  // Guardar el estado para mantener la persistencia
        
         // Guardar información para sincronización entre gráficos
         GlobalVariableSet(GLOBAL_VAR_PREFIX + Symbol() + "_Symbol", StringToDouble(Symbol()));
        
         // Guardar los precios actuales para sincronización
         if(entryLine != "") 
               GlobalVariableSet(GLOBAL_VAR_PREFIX + Symbol() + "_EntryPrice", GetLinePrice(entryLine));
         if(slLine != "") 
               GlobalVariableSet(GLOBAL_VAR_PREFIX + Symbol() + "_SLPrice", GetLinePrice(slLine));
         if(tpLine != "") 
               GlobalVariableSet(GLOBAL_VAR_PREFIX + Symbol() + "_TPPrice", GetLinePrice(tpLine));
        
         UpdatePriceLabels();
        
        
         // Actualizar el lotaje cuando se mueven las líneas de entry o SL
         if((sparam == entryLine || sparam == slLine) && entryLine != "" && slLine != "")
         {
               double entryPrice = GetLinePrice(entryLine);
               double slPrice = GetLinePrice(slLine);
                
               // Verificar que los precios sean válidos y diferentes para evitar división por cero
               if(entryPrice != 0 && slPrice != 0 && entryPrice != slPrice)
               {
                   double lotSize = CalculateLotSize(entryPrice, slPrice);
                   string orderType = GetOrderType(entryPrice, slPrice);
                   ObjectSetString(0, labelLot, OBJPROP_TEXT, orderType + " " + DoubleToString(lotSize, 2) + " lots");
                    
                   // También actualizar los valores de previsualización
 //                  ObjectSetString(0, buttonEntryPreview, OBJPROP_TEXT, DoubleToString(entryPrice, _Digits));
 //                  ObjectSetString(0, buttonSLPreview, OBJPROP_TEXT, DoubleToString(slPrice, _Digits));
               }
         }
        
        
        
        
         // Guardar el estado para sincronización
         SaveGlobalState();
      }
   }    
    // Eliminar líneas con la tecla Delete
    if(id == CHARTEVENT_KEYDOWN && lparam == 46)
    {
        if(ObjectGetInteger(0, sparam, OBJPROP_SELECTED))
        {
            if(sparam == entryLine) entryLine = "";
            if(sparam == slLine) slLine = "";
            if(sparam == tpLine) tpLine = "";
            ObjectDelete(0, sparam);
        }
    }
    
    // Actualizar etiquetas cuando se crean las líneas
    if(id == CHARTEVENT_OBJECT_CREATE)
    {
        if(sparam == slLine || sparam == tpLine)
        {
            UpdatePriceLabels();
        }
    }
    
    // Limpiar etiquetas cuando se eliminan las líneas
    if(id == CHARTEVENT_OBJECT_DELETE)
    {
        if(sparam == slLine)
        {
            ObjectDelete(0, labelSL);
        }
        if(sparam == tpLine)
        {
            ObjectDelete(0, labelTP);
        }
    }
    
    // Manejar edición de los botones de la segunda fila
    if(id == CHARTEVENT_OBJECT_ENDEDIT)
    {
        if(sparam == buttonEntryLevel || sparam == buttonSLLevel || sparam == buttonTPLevel)
        {
            string text = ObjectGetString(0, sparam, OBJPROP_TEXT);
            double price = StringToDouble(text);
            
            if(price != 0)
            {
                if(sparam == buttonEntryLevel)
                {
                    if(entryLine == "") entryLine = GetUniqueObjectName("Trade_Entry");
                    CreateTradeLine(entryLine, TimeCurrent(), price, LineColorBuy);
                }
                else if(sparam == buttonSLLevel)
                {
                    if(slLine == "") slLine = GetUniqueObjectName("Trade_SL");
                    CreateTradeLine(slLine, TimeCurrent(), price, LineColorSL);
                }
                else if(sparam == buttonTPLevel)
                {
                    if(tpLine == "") tpLine = GetUniqueObjectName("Trade_TP");
                    CreateTradeLine(tpLine, TimeCurrent(), price, LineColorTP);
                }
                UpdatePriceLabels();
            }
        }
        else if(sparam == "RiskInput")
        {
            string riskText = ObjectGetString(0, "RiskInput", OBJPROP_TEXT);
            double newRisk = StringToDouble(riskText);
            
            if(newRisk > 0)  // Validar que el riesgo sea positivo
            {
                currentRiskPercent = newRisk;
                ObjectSetString(0, buttonRisk, OBJPROP_TEXT, DoubleToString(currentRiskPercent, 2) + "%");
                UpdatePriceLabels();

                // Actualizar el lotaje si hay líneas de entrada y SL
                if(entryLine != "" && slLine != "")
                {
                   double slPrice = GetLinePrice(slLine);
                   double lastTick_ask = MarketInfo(Symbol(), MODE_ASK);
                   double lastTick_bid = MarketInfo(Symbol(), MODE_BID);
                   double marketPrice;
    
                   // Determinar si es compra o venta basado en la posición del SL
                   if(slPrice < lastTick_bid)  // Compra
                   {
                      marketPrice = lastTick_ask;
                   }
                   else  // Venta
                   {
                      marketPrice = lastTick_bid;
                   }
    
    // Calcular lotaje usando el precio actual del mercado
    double marketLotSize = CalculateMarketLotSize(marketPrice, slPrice);
    ObjectSetString(0, buttonLotSize, OBJPROP_TEXT, DoubleToString(marketLotSize, 2) + " lots");
    
    // Actualizar también la etiqueta de la línea con el lotaje basado en líneas
    double entryPrice = GetLinePrice(entryLine);
    double lineLotSize = CalculateLotSize(entryPrice, slPrice);
    ObjectSetString(0, labelLot, OBJPROP_TEXT, "Lot: " + DoubleToString(lineLotSize, 2));
}


            }
            else
            {
                Print("Error: El riesgo debe ser mayor que 0");
                ObjectSetString(0, "RiskInput", OBJPROP_TEXT, DoubleToString(currentRiskPercent, 3));
            }
            
            // Ocultar el campo de entrada después de la edición
            ObjectDelete(0, "RiskInput");
            ChartRedraw();
        }
    }
    
    // En el cambio de temporalidad, usar los valores stored para recrear las líneas
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        SaveGlobalState();      // Guardar estado antes del cambio
        RestoreGlobalState();   // Restaurar estado después del cambio
        return;
    }
}





//+------------------------------------------------------------------+
//| Crear botones                                                     |
//+------------------------------------------------------------------+
void CreateButtons()
{
    // Calcular posiciones Y para las filas
    yPos2 = (int)(yPos + buttonHeight + spacing); 
    yPos3 = (int)(yPos2 + buttonHeight + spacing); 
    
    // Primera fila - Botones principales
    // Botón Riesgo
    ObjectCreate(0, buttonRisk, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, buttonRisk, OBJPROP_XDISTANCE, xStart);
    ObjectSetInteger(0, buttonRisk, OBJPROP_YDISTANCE, yPos);
    ObjectSetInteger(0, buttonRisk, OBJPROP_XSIZE, buttonWidth);
    ObjectSetInteger(0, buttonRisk, OBJPROP_YSIZE, buttonHeight);
    ObjectSetString(0, buttonRisk, OBJPROP_TEXT, DoubleToString(currentRiskPercent, 2) + "%");
    ObjectSetInteger(0, buttonRisk, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, buttonRisk, OBJPROP_BGCOLOR, clrLightGray);
    ObjectSetInteger(0, buttonRisk, OBJPROP_FONTSIZE, 7);
    
    // Botón SL
    CreateButton(buttonSL, xStart + buttonWidth + spacing, yPos, "SL");
    
    // Botón TP
    CreateButton(buttonTP, xStart + (buttonWidth + spacing) * 2, yPos, "TP");
    
    // Botón Aplicar
    CreateButton(buttonApply, xStart + (buttonWidth + spacing) * 3, yPos, "Aplicar");
    
    // Botón Cancelar
    CreateButton(buttonCancel, xStart + (buttonWidth + spacing) * 4, yPos, "Cancelar");
    
    // Botón Ejecutar
    CreateButton(buttonExecute, xStart + (buttonWidth + spacing) * 5, yPos, "Ejecutar");
    
    // Botón Market (esquina superior derecha)
    CreateButton(buttonMarket, (int)(ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - buttonWidth - 10), yPos, "Market");
    
    // Segunda fila - Cuadros de texto
    // Cuadros de texto debajo de SL, TP y Entrada
    CreateTextEdit(buttonSLLevel, xStart + buttonWidth + spacing, yPos2);           // Debajo de SL
    CreateTextEdit(buttonTPLevel, xStart + (buttonWidth + spacing) * 2, yPos2);     // Debajo de TP
    CreateTextEdit(buttonEntryLevel, xStart + (buttonWidth + spacing) * 3, yPos2);  // Debajo de Entrada
    
    // Cuadro de texto para el lote (debajo de Market)
    CreateTextEdit(buttonLotSize, (int)(ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - buttonWidth - 10), yPos2);
    
    // Tercera fila - Botones
    // Botón Sync en primera columna
    CreateButton(buttonSync, xStart, yPos3, "Sinc");
    // Establecer color inicial del botón Sync a lightGreen
    ObjectSetInteger(0, buttonSync, OBJPROP_BGCOLOR, clrLightGreen);
    ObjectSetInteger(0, buttonSync, OBJPROP_COLOR, clrBlack);
        
    // Botones de preview
    CreatePreviewButton(buttonSLPreview, xStart + buttonWidth + spacing, yPos3);           // Columna SL
    CreatePreviewButton(buttonTPPreview, xStart + (buttonWidth + spacing) * 2, yPos3);     // Columna TP
    CreatePreviewButton(buttonEntryPreview, xStart + (buttonWidth + spacing) * 3, yPos3);  // Columna Entrada
    
    // Crear etiqueta para mostrar el spread
    if(ObjectFind(0, labelSpread) >= 0)
        ObjectDelete(0, labelSpread);
    
    ObjectCreate(0, labelSpread, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, labelSpread, OBJPROP_XDISTANCE, (int)(ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - 250));
    ObjectSetInteger(0, labelSpread, OBJPROP_YDISTANCE, yPos + buttonHeight + spacing + 20);
    ObjectSetInteger(0, labelSpread, OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(0, labelSpread, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, labelSpread, OBJPROP_TEXT, "Spread: 0.0000");
    
    // Crear cuadro de texto para mensajes de TP
    if(ObjectFind(0, labelTPMessage) >= 0)
        ObjectDelete(0, labelTPMessage);
    
    ObjectCreate(0, labelTPMessage, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, labelTPMessage, OBJPROP_XDISTANCE, xStart + (buttonWidth + spacing) * 2);
    ObjectSetInteger(0, labelTPMessage, OBJPROP_YDISTANCE, yPos3 + buttonHeight + 2);
    ObjectSetInteger(0, labelTPMessage, OBJPROP_XSIZE, buttonWidth * 3);
    ObjectSetInteger(0, labelTPMessage, OBJPROP_YSIZE, 20);
    ObjectSetInteger(0, labelTPMessage, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, labelTPMessage, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, labelTPMessage, OBJPROP_BORDER_COLOR, clrWhite);
    ObjectSetInteger(0, labelTPMessage, OBJPROP_FONTSIZE, 7);
    ObjectSetInteger(0, labelTPMessage, OBJPROP_READONLY, true);
    ObjectSetInteger(0, labelTPMessage, OBJPROP_SELECTABLE, false);
    ObjectSetString(0, labelTPMessage, OBJPROP_TEXT, "");
    ObjectSetInteger(0, labelTPMessage, OBJPROP_HIDDEN, true);
    ChartRedraw();
    
    // Inicialmente desactivar botones
    ObjectSetInteger(0, buttonApply, OBJPROP_STATE, false);
    ObjectSetInteger(0, buttonCancel, OBJPROP_STATE, false);
    ObjectSetInteger(0, buttonExecute, OBJPROP_STATE, false);
    ObjectSetInteger(0, buttonMarket, OBJPROP_STATE, false);
    ObjectSetInteger(0, buttonSync, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//| Función auxiliar para crear botones                               |
//+------------------------------------------------------------------+
void CreateButton(string name, int x, int y, string text)
{
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, 45);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, 15);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrLightGray);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
}

//+------------------------------------------------------------------+
//| Función auxiliar para crear cuadros de texto                      |
//+------------------------------------------------------------------+
void CreateTextEdit(string name, int x, int y)
{
    ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, 45);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, 15);
    ObjectSetString(0, name, OBJPROP_TEXT, "");
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
    ObjectSetInteger(0, name, OBJPROP_READONLY, true);
}

//+------------------------------------------------------------------+
//| Función auxiliar para crear botones de preview                    |
//+------------------------------------------------------------------+
void CreatePreviewButton(string name, int x, int y)
{
    ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, 45);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, 15);
    ObjectSetString(0, name, OBJPROP_TEXT, "");
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
    ObjectSetInteger(0, name, OBJPROP_READONLY, false);
}
//+------------------------------------------------------------------+
//| Función auxiliar para determinar el tipo de operación             |
//+------------------------------------------------------------------+
string GetOrderType(double entryPrice, double slPrice)
{
    double lastTick_ask = MarketInfo(Symbol(), MODE_ASK);  // Equivalente a lastTick.ask
    double lastTick_bid = MarketInfo(Symbol(), MODE_BID);  // Equivalente a lastTick.bid
    double tpPrice = GetLinePrice(tpLine);
    double spread = lastTick_ask - lastTick_bid;
    
    // Informar sobre el spread detectado
    Print("[SPREAD INFO] Spread actual: ", DoubleToString(spread, _Digits), " | Ask: ", DoubleToString(lastTick_ask, _Digits), " | Bid: ", DoubleToString(lastTick_bid, _Digits));
    
    // Validar que TP no esté entre Entry y SL
    if(tpPrice != 0)
    {
        if((tpPrice > MathMin(entryPrice, slPrice) && tpPrice < MathMax(entryPrice, slPrice)))
        {
            return "Error: TP no puede estar entre Entry y SL";
        }
    }
    
    // Es una operación de compra
    if(slPrice < entryPrice)
    {
        if(entryPrice > lastTick_ask)  // Orden por encima del mercado
        {
            if(tpPrice != 0 && tpPrice < entryPrice)
            {
                return "Error: TP debe estar por encima de Entry en Buy Stop";
            }
            // Si el precio actual cruza el nivel de entrada
            if(lastTick_ask >= entryPrice)
            {
                return "Error: Precio actual en nivel de entrada";
            }
            return "Buy Stop";
        }
        else if(entryPrice < lastTick_bid)  // Orden por debajo del mercado
        {
            if(tpPrice != 0 && tpPrice < entryPrice)
            {
                return "Error: TP debe estar por encima de Entry en Buy Limit";
            }
            // Si el precio actual cruza el nivel de entrada
            if(lastTick_bid <= entryPrice)
            {
                return "Error: Precio actual en nivel de entrada";
            }
            return "Buy Limit";
        }
        else
        {
            if(tpPrice != 0 && tpPrice < entryPrice)
            {
                return "Error: TP debe estar por encima de Entry en Buy";
            }
            return "Buy";
        }
    }
    // Es una operación de venta
    else
    {
        if(entryPrice < lastTick_bid)  // Orden por debajo del mercado
        {
            if(tpPrice != 0 && tpPrice > entryPrice)
            {
                return "Error: TP debe estar por debajo de Entry en Sell Stop";
            }
            // Si el precio actual cruza el nivel de entrada
            if(lastTick_bid <= entryPrice)
            {
                return "Error: Precio actual en nivel de entrada";
            }
            return "Sell Stop";
        }
        else if(entryPrice > lastTick_ask)  // Orden por encima del mercado
        {
            if(tpPrice != 0 && tpPrice > entryPrice)
            {
                return "Error: TP debe estar por debajo de Entry en Sell Limit";
            }
            // Si el precio actual cruza el nivel de entrada
            if(lastTick_ask >= entryPrice)
            {
                return "Error: Precio actual en nivel de entrada";
            }
            return "Sell Limit";
        }
        else
        {
            if(tpPrice != 0 && tpPrice > entryPrice)
            {
                return "Error: TP debe estar por debajo de Entry en Sell";
            }
            return "Sell";
        }
    }
}

//+------------------------------------------------------------------+
//| Función auxiliar para validar el SL                               |
//+------------------------------------------------------------------+
string ValidateSL(double entryPrice, double slPrice)
{
    double lastTick_ask = MarketInfo(Symbol(), MODE_ASK);  // Equivalente a lastTick.ask
    double lastTick_bid = MarketInfo(Symbol(), MODE_BID);  // Equivalente a lastTick.bid
    
    // Para operaciones de compra
    if(slPrice < entryPrice)
    {
        if(entryPrice > lastTick_ask || entryPrice < lastTick_bid)  // Buy Stop o Buy Limit
        {
            if(slPrice >= lastTick_ask)
            {
                return "Error: SL debe estar por debajo del precio actual";
            }
        }
    }
    // Para operaciones de venta
    else
    {
        if(entryPrice < lastTick_bid || entryPrice > lastTick_ask)  // Sell Stop o Sell Limit
        {
            if(slPrice <= lastTick_bid)
            {
                return "Error: SL debe estar por encima del precio actual";
            }
        }
    }
    
    return "";
}

//+------------------------------------------------------------------+
//| Función para crear/actualizar etiquetas de precio                 |
//+------------------------------------------------------------------+
void UpdatePriceLabels()
{
    double entryPrice = GetLinePrice(entryLine);
    double slPrice = GetLinePrice(slLine);
    double tpPrice = GetLinePrice(tpLine);
    
    // Actualizar SOLO los botones de la segunda fila
    if(entryPrice != 0)
        ObjectSetString(0, buttonEntryLevel, OBJPROP_TEXT, DoubleToString(entryPrice, _Digits));
    else
        ObjectSetString(0, buttonEntryLevel, OBJPROP_TEXT, "");
        
    if(slPrice != 0)
        ObjectSetString(0, buttonSLLevel, OBJPROP_TEXT, DoubleToString(slPrice, _Digits));
    else
        ObjectSetString(0, buttonSLLevel, OBJPROP_TEXT, "");
        
    if(tpPrice != 0)
        ObjectSetString(0, buttonTPLevel, OBJPROP_TEXT, DoubleToString(tpPrice, _Digits));
    else
        ObjectSetString(0, buttonTPLevel, OBJPROP_TEXT, "");
    
    // NO actualizar los botones stored bajo ninguna circunstancia
    
    // Controlar visibilidad del botón Market y su lotaje
    bool showMarketButton = false;
    
    if(entryLine != "" && slLine != "")
    {
        string orderType = GetOrderType(entryPrice, slPrice);
        string slError = ValidateSL(entryPrice, slPrice);
        
        // Mostrar botón solo si no hay errores
        if(StringFind(orderType, "Error") < 0 && slError == "")
        {
            showMarketButton = true;
            // Actualizar color del botón a verde cuando está activo
            ObjectSetInteger(0, buttonMarket, OBJPROP_BGCOLOR, clrDarkGreen);
            
            double lastTick_ask = MarketInfo(Symbol(), MODE_ASK);  // Equivalente a lastTick.ask
            double lastTick_bid = MarketInfo(Symbol(), MODE_BID);  // Equivalente a lastTick.bid
            double marketPrice;
            
            // Determinar si es compra o venta basado en la posición del SL
            if(slPrice < entryPrice)  // Operación de compra
            {
                marketPrice = lastTick_ask;
            }
            else  // Operación de venta
            {
                marketPrice = lastTick_bid;
            }
            
             //Calcular lotaje usando el precio actual del mercado
            double marketLotSize = CalculateMarketLotSize(marketPrice, slPrice);
            ObjectSetString(0, buttonLotSize, OBJPROP_TEXT, DoubleToString(marketLotSize, 2) + " lots");
        }
        else
        {
            ObjectSetInteger(0, buttonMarket, OBJPROP_BGCOLOR, clrDarkGray);
            ObjectSetString(0, buttonLotSize, OBJPROP_TEXT, "");
        }
    }
    else
    {
        ObjectSetString(0, buttonLotSize, OBJPROP_TEXT, "");
    }
    
    ObjectSetInteger(0, buttonMarket, OBJPROP_HIDDEN, !showMarketButton);
    ObjectSetInteger(0, buttonLotSize, OBJPROP_HIDDEN, !showMarketButton);
    
    datetime time = TimeCurrent();
    double pointSize = Point;  // Equivalente a SYMBOL_POINT
    int pipsOffset = 10; // Distancia en pips para desplazar las etiquetas
    
    // Actualizar etiqueta de lotaje
    if(entryLine != "")
    {
        slPrice = GetLinePrice(slLine); 
        if(slPrice != 0 && entryPrice != 0)
        {
            double lotSize = CalculateLotSize(entryPrice, slPrice);
            string orderType = GetOrderType(entryPrice, slPrice);
            
            if(ObjectFind(0, labelLot) < 0)
            {
               ObjectCreate(0, labelLot, OBJ_TEXT, 0, time, entryPrice);
            }
            ObjectSetInteger(0, labelLot, OBJPROP_COLOR, LineColorBuy);
            ObjectSetInteger(0, labelLot, OBJPROP_FONTSIZE, 7);
            ObjectSetString(0, labelLot, OBJPROP_TEXT, orderType + " " + DoubleToString(lotSize, 2) + " lots");
            ObjectSetDouble(0, labelLot, OBJPROP_PRICE, entryPrice + (10 * Point)); // 5 pips por encima
            // Usar la primera fecha visible en el gráfico
            datetime firstVisibleTime = Time[WindowFirstVisibleBar()];
            ObjectSetInteger(0, labelLot, OBJPROP_TIME, firstVisibleTime);            
            ObjectSetInteger(0, labelLot, OBJPROP_ANCHOR, ANCHOR_LEFT);
            ObjectSetInteger(0, labelLot, OBJPROP_BACK, false);
        }
    }
    else
    {
        ObjectDelete(0, labelLot);
    }
    
    // Actualizar etiqueta SL
    if(slLine != "")
    {
        slPrice = GetLinePrice(slLine);
        if(slPrice != 0 && entryPrice != 0)
        {
            string slError = ValidateSL(entryPrice, slPrice);
            double riskAmount = AccountBalance() * (currentRiskPercent / 100.0);  // Equivalente a ACCOUNT_BALANCE
            
            if(ObjectFind(0, labelSL) < 0)
            {
                ObjectCreate(0, labelSL, OBJ_TEXT, 0, time, slPrice);
            }
            ObjectSetInteger(0, labelSL, OBJPROP_COLOR, slError != "" ? clrRed : LineColorSL);
            ObjectSetInteger(0, labelSL, OBJPROP_FONTSIZE, 7);
            ObjectSetString(0, labelSL, OBJPROP_TEXT, slError != "" ? slError : "SL " + DoubleToString(riskAmount, 2) + " $");
            ObjectSetDouble(0, labelSL, OBJPROP_PRICE, slPrice + (10 * Point)); // 5 pips por encima
            // Usar la primera fecha visible en el gráfico
            datetime firstVisibleTime = Time[WindowFirstVisibleBar()];
            ObjectSetInteger(0, labelSL, OBJPROP_TIME, firstVisibleTime);            
            ObjectSetInteger(0, labelSL, OBJPROP_ANCHOR, ANCHOR_LEFT);
            ObjectSetInteger(0, labelSL, OBJPROP_BACK, false);
        }
    }
    else
    {
        ObjectDelete(0, labelSL);
    }
    
    // Actualizar etiqueta TP
    if(tpLine != "")
    {
        tpPrice = GetLinePrice(tpLine);
        slPrice = GetLinePrice(slLine);
        if(tpPrice != 0 && entryPrice != 0 && slPrice != 0)
        {
            double riskPips = MathAbs(entryPrice - slPrice) / pointSize;
            double rewardPips = MathAbs(tpPrice - entryPrice) / pointSize;
            double riskAmount = AccountBalance() * (currentRiskPercent / 100.0);  // Equivalente a ACCOUNT_BALANCE
            double rewardAmount = (rewardPips / riskPips) * riskAmount;
            
            if(ObjectFind(0, labelTP) < 0)
            {
                ObjectCreate(0, labelTP, OBJ_TEXT, 0, time, tpPrice);
            }
            ObjectSetInteger(0, labelTP, OBJPROP_COLOR, LineColorTP);
            ObjectSetInteger(0, labelTP, OBJPROP_FONTSIZE, 7);
            ObjectSetString(0, labelTP, OBJPROP_TEXT, "TP " + DoubleToString(rewardAmount, 2)+ " $");
            ObjectSetDouble(0, labelTP, OBJPROP_PRICE, tpPrice + (10 * Point)); // 5 pips por encima
            // Usar la primera fecha visible en el gráfico
            datetime firstVisibleTime = Time[WindowFirstVisibleBar()];
            ObjectSetInteger(0, labelTP, OBJPROP_TIME, firstVisibleTime);            
            ObjectSetInteger(0, labelTP, OBJPROP_ANCHOR, ANCHOR_LEFT);
            ObjectSetInteger(0, labelTP, OBJPROP_BACK, false);
        }
    }
    else
    {
        ObjectDelete(0, labelTP);
    }
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Añadir OnTimer para monitorear cambios                            |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Actualizar el spread en tiempo real
    double ask = MarketInfo(Symbol(), MODE_ASK);
    double bid = MarketInfo(Symbol(), MODE_BID);
    double spread = ask - bid;
    ObjectSetString(0, labelSpread, OBJPROP_TEXT, "Spread: " + DoubleToString(spread, _Digits));
    
    // Verificar si estamos en el símbolo correcto
    if(GlobalVariableCheck(GLOBAL_VAR_PREFIX + Symbol() + "_Symbol"))
    {
        string savedSymbol = DoubleToString(GlobalVariableGet(GLOBAL_VAR_PREFIX + Symbol() + "_Symbol"), 0);
        if(savedSymbol == Symbol())
        {
            // Sincronizar línea de entrada
            if(GlobalVariableCheck(GLOBAL_VAR_PREFIX + Symbol() + "_EntryPrice"))
            {
                double price = GlobalVariableGet(GLOBAL_VAR_PREFIX + Symbol() + "_EntryPrice");
                if(price != 0 && price != GetLinePrice(entryLine))
                {
                    entryLine = GetUniqueObjectName("Trade_Entry");
                    CreateTradeLine(entryLine, TimeCurrent(), price, LineColorBuy);
                }
            }
            
            // Sincronizar línea de SL
            if(GlobalVariableCheck(GLOBAL_VAR_PREFIX + Symbol() + "_SLPrice"))
            {
                double price = GlobalVariableGet(GLOBAL_VAR_PREFIX + Symbol() + "_SLPrice");
                if(price != 0 && price != GetLinePrice(slLine))
                {
                    slLine = GetUniqueObjectName("Trade_SL");
                    CreateTradeLine(slLine, TimeCurrent(), price, LineColorSL);
                }
            }
            
            // Sincronizar línea de TP
            if(GlobalVariableCheck(GLOBAL_VAR_PREFIX + Symbol() + "_TPPrice"))
            {
                double price = GlobalVariableGet(GLOBAL_VAR_PREFIX + Symbol() + "_TPPrice");
                if(price != 0 && price != GetLinePrice(tpLine))
                {
                    tpLine = GetUniqueObjectName("Trade_TP");
                    CreateTradeLine(tpLine, TimeCurrent(), price, LineColorTP);
                }
            }
            
            UpdatePriceLabels();
            UpdateMarketLot();  // Llamar a la función que actualiza el lote
            UpdateMarketButtonLot(); // Actualizar específicamente el lote del botón Market
            ChartRedraw();
        }
    }
}

//+------------------------------------------------------------------+
//| Actualizar lote de operación a mercado                            |
//+------------------------------------------------------------------+
void UpdateMarketLot()
{
    // Solo actualizar si hay línea de SL
    if(slLine != "" && ObjectFind(0, slLine) >= 0)
    {
        double lastTick_ask = MarketInfo(Symbol(), MODE_ASK);
        double lastTick_bid = MarketInfo(Symbol(), MODE_BID);
        double slPrice = GetLinePrice(slLine);
        double marketPrice;
        
        // Determinar si es compra o venta basado en la posición del SL
        if(slPrice < lastTick_bid)  // Compra si SL está por debajo del precio actual
        {
            marketPrice = lastTick_ask;
        }
        else  // Venta si SL está por encima
        {
            marketPrice = lastTick_bid;
        }
        
        // Verificar que los precios sean válidos para evitar división por cero
        if(marketPrice != 0 && slPrice != 0 && marketPrice != slPrice)
        {
            // Calcular lotaje usando el precio actual del mercado
            double marketLotSize = CalculateMarketLotSize(marketPrice, slPrice);
            ObjectSetString(0, buttonLotSize, OBJPROP_TEXT, DoubleToString(marketLotSize, 2) + " lots");
        }
    }
}

//+------------------------------------------------------------------+
//| Añadir función para guardar los valores                           |
//+------------------------------------------------------------------+
void SaveLineValues()
{
    if(entryLine != "")
        GlobalVariableSet(GLOBAL_VAR_PREFIX + Symbol() + "_Entry", GetLinePrice(entryLine));
    if(slLine != "")
        GlobalVariableSet(GLOBAL_VAR_PREFIX + Symbol() + "_SL", GetLinePrice(slLine));
    if(tpLine != "")
        GlobalVariableSet(GLOBAL_VAR_PREFIX + Symbol() + "_TP", GetLinePrice(tpLine));
}

//+------------------------------------------------------------------+
//| Añadir función para restaurar los valores                         |
//+------------------------------------------------------------------+
void RestoreLineValues()
{
    if(GlobalVariableCheck(GLOBAL_VAR_PREFIX + Symbol() + "_Entry"))
    {
        double price = GlobalVariableGet(GLOBAL_VAR_PREFIX + Symbol() + "_Entry");
        if(price != 0)
        {
            entryLine = GetUniqueObjectName("Trade_Entry");
            CreateTradeLine(entryLine, TimeCurrent(), price, LineColorBuy);
        }
    }
    
    if(GlobalVariableCheck(GLOBAL_VAR_PREFIX + Symbol() + "_SL"))
    {
        double price = GlobalVariableGet(GLOBAL_VAR_PREFIX + Symbol() + "_SL");
        if(price != 0)
        {
            slLine = GetUniqueObjectName("Trade_SL");
            CreateTradeLine(slLine, TimeCurrent(), price, LineColorSL);
        }
    }
    
    if(GlobalVariableCheck(GLOBAL_VAR_PREFIX + Symbol() + "_TP"))
    {
        double price = GlobalVariableGet(GLOBAL_VAR_PREFIX + Symbol() + "_TP");
        if(price != 0)
        {
            tpLine = GetUniqueObjectName("Trade_TP");
            CreateTradeLine(tpLine, TimeCurrent(), price, LineColorTP);
        }
    }
    
    UpdatePriceLabels();
}

//+------------------------------------------------------------------+
//| Limpieza de datos, líneas y botones                              |
//+------------------------------------------------------------------+
void LimpiezaDatosLineas()
{
    // Limpiar todas las líneas y etiquetas
    ObjectDelete(0, entryLine);
    ObjectDelete(0, slLine);
    ObjectDelete(0, tpLine);
    ObjectDelete(0, labelSL);
    ObjectDelete(0, labelTP);
    ObjectDelete(0, labelLot);
    entryLine = "";
    slLine = "";
    tpLine = "";

    // Eliminar variables globales
    GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_EntryPrice");
    GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_SLPrice");
    GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_TPPrice");
    GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_SLActive");
    GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_TPActive");
    GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_LotSize");
    GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_SLPreview");
    GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_TPPreview");
    GlobalVariableDel(GLOBAL_VAR_PREFIX + Symbol() + "_EntryPreview");
    ObjectSetString(0, buttonEntryLevel, OBJPROP_TEXT, "");
    ObjectSetString(0, buttonSLLevel, OBJPROP_TEXT, "");
    ObjectSetString(0, buttonTPLevel, OBJPROP_TEXT, "");

    // Desactivar botones SL y TP
    slActive = false;
    tpActive = false;
    ObjectSetInteger(0, buttonSL, OBJPROP_BGCOLOR, clrLightGray);
    ObjectSetInteger(0, buttonSL, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, buttonTP, OBJPROP_BGCOLOR, clrLightGray);
    ObjectSetInteger(0, buttonTP, OBJPROP_COLOR, clrBlack);

    // Desactivar botón Aplicar
    ObjectSetInteger(0, buttonApply, OBJPROP_STATE, false);
    ObjectSetInteger(0, buttonApply, OBJPROP_BGCOLOR, clrLightGray);
    ObjectSetInteger(0, buttonApply, OBJPROP_COLOR, clrBlack);
    
    // Desactivar botón Sincro
    ObjectSetInteger(0, buttonSync, OBJPROP_BGCOLOR, clrLightGreen);
    ObjectSetInteger(0, buttonSync, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, buttonSync, OBJPROP_STATE, false);

    // Desactivar y ocultar el botón Market y su lotaje
    ObjectSetInteger(0, buttonMarket, OBJPROP_BGCOLOR, clrDarkGray);
    ObjectSetInteger(0, buttonMarket, OBJPROP_STATE, false);
    ObjectSetString(0, buttonLotSize, OBJPROP_TEXT, "");
    ObjectSetInteger(0, buttonLotSize, OBJPROP_HIDDEN, true);
    
    // Eliminar líneas en todos los gráficos
    DeleteLinesAndArrows();
    
    // Eliminar variables globales
    string symbolPrefix = GLOBAL_VAR_PREFIX + Symbol() + "_";
    GlobalVariableDel(symbolPrefix + "Entry");
    GlobalVariableDel(symbolPrefix + "SL");
    GlobalVariableDel(symbolPrefix + "TP");
    GlobalVariableDel(symbolPrefix + "SLActive");
    GlobalVariableDel(symbolPrefix + "TPActive");
    GlobalVariableDel(symbolPrefix + "SLPreview");
    GlobalVariableDel(symbolPrefix + "TPPreview");
    GlobalVariableDel(symbolPrefix + "EntryPreview");
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Eliminar líneas y arrows                                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Eliminar líneas en todos los gráficos                           |
//+------------------------------------------------------------------+
void DeleteLinesInAllCharts(string tempEntryLine="", string tempSLLine="", string tempTPLine="")
{
    string currentSymbol = Symbol();
    long currentChartID = ChartID();
    int deletedCount = 0;
    
    // Usar los nombres temporales si se proporcionan, si no usar las variables globales
    string entryName = tempEntryLine != "" ? tempEntryLine : entryLine;
    string slName = tempSLLine != "" ? tempSLLine : slLine;
    string tpName = tempTPLine != "" ? tempTPLine : tpLine;
    
    // Primero borrar las líneas en el gráfico actual
    if(entryName != "")
        if(ObjectFind(currentChartID, entryName) >= 0)
            if(ObjectDelete(currentChartID, entryName))
                deletedCount++;
                
    if(slName != "")
        if(ObjectFind(currentChartID, slName) >= 0)
            if(ObjectDelete(currentChartID, slName))
                deletedCount++;
                
    if(tpName != "")
        if(ObjectFind(currentChartID, tpName) >= 0)
            if(ObjectDelete(currentChartID, tpName))
                deletedCount++;
    
    // Luego borrar en otros gráficos
    long chartID = ChartFirst();
    
    while(chartID >= 0)
    {
        if(ChartSymbol(chartID) == currentSymbol && chartID != ChartID())
        {
            // Eliminar líneas en cada gráfico si existen
            if(entryName != "")
            {
                if(ObjectFind(chartID, entryName) >= 0)
                {
                    ObjectDelete(chartID, entryName);
                    deletedCount++;
                }
            }
            
            if(slName != "")
            {
                if(ObjectFind(chartID, slName) >= 0)
                {
                    ObjectDelete(chartID, slName);
                    deletedCount++;
                }
            }
            
            if(tpName != "")
            {
                if(ObjectFind(chartID, tpName) >= 0)
                {
                    ObjectDelete(chartID, tpName);
                    deletedCount++;
                }
            }
            
            // Eliminar etiquetas
            ObjectDelete(chartID, labelSL);
            ObjectDelete(chartID, labelTP);
            ObjectDelete(chartID, labelLot);
            
            ChartRedraw(chartID);
        }
        chartID = ChartNext(chartID);
    }
    
    Print("Líneas eliminadas en gráficos: ", deletedCount);
}

//+------------------------------------------------------------------+
//| Eliminar líneas y arrows                                          |
//+------------------------------------------------------------------+
void DeleteLinesAndArrows()
{
    // Guardar nombres de las líneas antes de borrarlas
    string tempEntryLine = entryLine;
    string tempSLLine = slLine;
    string tempTPLine = tpLine;
    
    // Eliminar líneas en todos los gráficos usando los nombres guardados
    DeleteLinesInAllCharts(tempEntryLine, tempSLLine, tempTPLine);
    
    // Limpiar nombres de líneas
    entryLine = "";
    slLine = "";
    tpLine = "";
    
    // Añadir limpieza de arrows
    int total = ObjectsTotal();
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(i);
        if(ObjectType(name) == OBJ_ARROW_BUY || 
           ObjectType(name) == OBJ_ARROW_SELL ||
           ObjectType(name) == OBJ_ARROW)
        {
            ObjectDelete(name);
        }
    }
    
    ChartRedraw();
}
