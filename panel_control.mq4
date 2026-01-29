#property copyright "Your Name"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window

extern string INDICATOR_ID = "PanelControl1";

struct ZoneInfo {
    string name;      // Nombre de la zona (ZC_x o ZV_x)
    string type;      // ZC o ZV
    datetime time1;   // Tiempo inicial
    datetime time2;   // Tiempo final
    double price1;    // Precio inicial
    double price2;    // Precio final
    int timeframe;    // Timeframe donde se creó
};

struct SymbolInfo {
    string name;
    bool fav1;        // Primera casilla
    bool fav2;        // Segunda casilla
    ZoneInfo zones[]; // Array de zonas para este símbolo
    bool inBuyZone;   // Indica si el precio está en zona de compra
    bool inSellZone;  // Indica si el precio está en zona de venta
    string activeZones; // String con información de zonas activas
};

SymbolInfo symbolList[];
int totalSymbols = 0;
string listName = "SymbolList";
int listWidth = 400;  // Aumentado para acomodar precios y zonas
int startX = 10;
int startY = 45;
string sortButton = "SortButton";
int currentSortMode = 0;
string favoritesFile;

string PeriodToString(int period) {
    switch(period) {
        case PERIOD_M1:  return "M1";
        case PERIOD_M5:  return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_H1:  return "H1";
        case PERIOD_H4:  return "H4";
        case PERIOD_D1:  return "D1";
        default: return IntegerToString(period);
    }
}

void SortTimeframes(int& timeframes[]) {
    int size = ArraySize(timeframes);
    for(int i = 0; i < size - 1; i++) {
        for(int j = i + 1; j < size; j++) {
            if(timeframes[i] < timeframes[j]) {
                int temp = timeframes[i];
                timeframes[i] = timeframes[j];
                timeframes[j] = temp;
            }
        }
    }
}

int OnInit() {
    favoritesFile = "SymbolFavorites_" + IntegerToString(AccountNumber()) + ".txt";
    
    // Ocultar completamente el gráfico base
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    ChartSetInteger(0, CHART_SHOW_ASK_LINE, false);
    ChartSetInteger(0, CHART_SHOW_BID_LINE, false);
    ChartSetInteger(0, CHART_SHOW_LAST_LINE, false);
    ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, false);
    ChartSetInteger(0, CHART_SHOW_OHLC, false);
    ChartSetInteger(0, CHART_SHOW_VOLUMES, false);
    ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrWhite);
    ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhite);
    ChartSetInteger(0, CHART_COLOR_GRID, clrWhite);
    ChartSetInteger(0, CHART_COLOR_CHART_UP, clrWhite);
    ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrWhite);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrWhite);
    ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrWhite);
    ChartSetInteger(0, CHART_SCALE, 0);
    ChartSetInteger(0, CHART_SHOW_DATE_SCALE, false);
    ChartSetInteger(0, CHART_SHOW_PRICE_SCALE, false);
    
    // Cargar datos iniciales
    LoadMarketWatchSymbols();
    LoadFavorites();
    LoadZones();
    
    // Crear interfaz
    CreateSortButton();
    CreateSymbolList();
    
    // Configurar temporizador para actualizaciones frecuentes
    EventSetTimer(1);
    
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    EventKillTimer();
    SaveFavorites();
    ObjectDelete(0, "ListBackground");
    ObjectDelete(0, sortButton);
    for(int i = 0; i < totalSymbols; i++) {
        ObjectDelete(0, "Symbol_" + IntegerToString(i));
        ObjectDelete(0, "Check1_" + IntegerToString(i));
        ObjectDelete(0, "Check2_" + IntegerToString(i));
    }
}

void OnTimer() {
    UpdatePanel();
}

void UpdatePanel() {
    LoadZones();              // Recargar solo zonas
    CheckPriceInZones();      // Verificar estados
    CreateSymbolList();       // Actualizar visual
    ChartRedraw();           // Forzar redibujado
}

void CreateSortButton() {
    ObjectCreate(0, sortButton, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, sortButton, OBJPROP_XDISTANCE, startX);
    ObjectSetInteger(0, sortButton, OBJPROP_YDISTANCE, 10);
    ObjectSetInteger(0, sortButton, OBJPROP_XSIZE, 100);
    ObjectSetInteger(0, sortButton, OBJPROP_YSIZE, 25);
    ObjectSetString(0, sortButton, OBJPROP_TEXT, "Ordenar: A-Z");
    ObjectSetInteger(0, sortButton, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, sortButton, OBJPROP_BGCOLOR, C'220,220,220');
    ObjectSetInteger(0, sortButton, OBJPROP_BORDER_COLOR, clrGray);
}

void CreateSymbolList() {
    int lineHeight = 20;
    int checkboxSize = 15;
    
    ObjectCreate(0, "ListBackground", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "ListBackground", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "ListBackground", OBJPROP_XDISTANCE, startX - 5);
    ObjectSetInteger(0, "ListBackground", OBJPROP_YDISTANCE, startY - 5);
    ObjectSetInteger(0, "ListBackground", OBJPROP_XSIZE, listWidth);
    ObjectSetInteger(0, "ListBackground", OBJPROP_YSIZE, (totalSymbols * lineHeight) + 10);
    ObjectSetInteger(0, "ListBackground", OBJPROP_BGCOLOR, C'220,220,220');
    ObjectSetInteger(0, "ListBackground", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, "ListBackground", OBJPROP_COLOR, clrBlack);
    
    for(int i = 0; i < totalSymbols; i++) {
        string objName = "Symbol_" + IntegerToString(i);
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, startX + 50);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, startY + (i * lineHeight));
        
        double currentPrice = SymbolInfoDouble(symbolList[i].name, SYMBOL_BID);
        int digits = (int)SymbolInfoInteger(symbolList[i].name, SYMBOL_DIGITS);
        
        string displayText = StringFormat("%-10s %12s%s", 
            symbolList[i].name, 
            DoubleToString(currentPrice, digits),
            symbolList[i].activeZones);
        
        ObjectSetString(0, objName, OBJPROP_TEXT, displayText);
        
        color textColor = (symbolList[i].inBuyZone || symbolList[i].inSellZone) ? clrMagenta : clrNavy;
        ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, true);
        
        string check1Name = "Check1_" + IntegerToString(i);
        ObjectCreate(0, check1Name, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, check1Name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, check1Name, OBJPROP_XDISTANCE, startX + 5);
        ObjectSetInteger(0, check1Name, OBJPROP_YDISTANCE, startY + (i * lineHeight));
        ObjectSetInteger(0, check1Name, OBJPROP_XSIZE, checkboxSize);
        ObjectSetInteger(0, check1Name, OBJPROP_YSIZE, checkboxSize);
        ObjectSetString(0, check1Name, OBJPROP_TEXT, "");
        ObjectSetInteger(0, check1Name, OBJPROP_BGCOLOR, symbolList[i].fav1 ? clrRed : clrWhite);
        ObjectSetInteger(0, check1Name, OBJPROP_BORDER_COLOR, clrGray);
        
        string check2Name = "Check2_" + IntegerToString(i);
        ObjectCreate(0, check2Name, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, check2Name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, check2Name, OBJPROP_XDISTANCE, startX + 25);
        ObjectSetInteger(0, check2Name, OBJPROP_YDISTANCE, startY + (i * lineHeight));
        ObjectSetInteger(0, check2Name, OBJPROP_XSIZE, checkboxSize);
        ObjectSetInteger(0, check2Name, OBJPROP_YSIZE, checkboxSize);
        ObjectSetString(0, check2Name, OBJPROP_TEXT, "");
        ObjectSetInteger(0, check2Name, OBJPROP_BGCOLOR, symbolList[i].fav2 ? clrRed : clrWhite);
        ObjectSetInteger(0, check2Name, OBJPROP_BORDER_COLOR, clrGray);
    }
}
void CheckPriceInZones() {
    for(int i = 0; i < totalSymbols; i++) {
        double currentPrice = MarketInfo(symbolList[i].name, MODE_BID);
        symbolList[i].inBuyZone = false;
        symbolList[i].inSellZone = false;
        symbolList[i].activeZones = "";
        
        int buyTimeframes[];
        int sellTimeframes[];
        ArrayResize(buyTimeframes, 0);
        ArrayResize(sellTimeframes, 0);
        
        for(int j = 0; j < ArraySize(symbolList[i].zones); j++) {
            double minPrice = MathMin(symbolList[i].zones[j].price1, symbolList[i].zones[j].price2);
            double maxPrice = MathMax(symbolList[i].zones[j].price1, symbolList[i].zones[j].price2);
            
            if(currentPrice >= minPrice && currentPrice <= maxPrice) {
                if(symbolList[i].zones[j].type == "ZC") {
                    symbolList[i].inBuyZone = true;
                    ArrayResize(buyTimeframes, ArraySize(buyTimeframes) + 1);
                    buyTimeframes[ArraySize(buyTimeframes) - 1] = symbolList[i].zones[j].timeframe;
                }
                else if(symbolList[i].zones[j].type == "ZV") {
                    symbolList[i].inSellZone = true;
                    ArrayResize(sellTimeframes, ArraySize(sellTimeframes) + 1);
                    sellTimeframes[ArraySize(sellTimeframes) - 1] = symbolList[i].zones[j].timeframe;
                }
            }
        }
        
        SortTimeframes(sellTimeframes);
        SortTimeframes(buyTimeframes);
        
        for(int j = 0; j < ArraySize(sellTimeframes); j++) {
            symbolList[i].activeZones += " [V-" + PeriodToString(sellTimeframes[j]) + "]";
        }
        for(int j = 0; j < ArraySize(buyTimeframes); j++) {
            symbolList[i].activeZones += " [C-" + PeriodToString(buyTimeframes[j]) + "]";
        }
    }
}

void SortSymbols() {
    for(int i = 0; i < totalSymbols - 1; i++) {
        for(int j = i + 1; j < totalSymbols; j++) {
            bool shouldSwap = false;
            
            if(currentSortMode == 0) // A-Z
                shouldSwap = symbolList[i].name > symbolList[j].name;
            else if(currentSortMode == 1) // Z-A
                shouldSwap = symbolList[i].name < symbolList[j].name;
            else if(currentSortMode == 2) { // Favoritos + A-Z
                int favI = (symbolList[i].fav2 ? 2 : 0) + (symbolList[i].fav1 ? 1 : 0);
                int favJ = (symbolList[j].fav2 ? 2 : 0) + (symbolList[j].fav1 ? 1 : 0);
                
                if(favI < favJ)
                    shouldSwap = true;
                else if(favI == favJ)
                    shouldSwap = symbolList[i].name > symbolList[j].name;
            }
            
            if(shouldSwap) {
                SymbolInfo temp = symbolList[i];
                symbolList[i] = symbolList[j];
                symbolList[j] = temp;
            }
        }
    }
}

void ChangeAllChartsSymbol(string symbol) {
    long chartID = ChartFirst();
    while(chartID >= 0) {
        if(chartID != ChartID()) {
            ENUM_TIMEFRAMES timeframe = (ENUM_TIMEFRAMES)ChartPeriod(chartID);
            ChartSetSymbolPeriod(chartID, symbol, timeframe);
        }
        chartID = ChartNext(chartID);
    }
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    if(id == CHARTEVENT_OBJECT_CLICK) {
        if(sparam == sortButton) {
            currentSortMode = (currentSortMode + 1) % 3;
            string sortText = "Ordenar: ";
            switch(currentSortMode) {
                case 0: sortText += "A-Z"; break;
                case 1: sortText += "Z-A"; break;
                case 2: sortText += "FAV"; break;
            }
            ObjectSetString(0, sortButton, OBJPROP_TEXT, sortText);
            SortSymbols();
            CreateSymbolList();
            return;
        }
        
        if(StringFind(sparam, "Check1_") == 0) {
            int index = (int)StringToInteger(StringSubstr(sparam, 7));
            ToggleCheckbox(index, true);
            return;
        }
        
        if(StringFind(sparam, "Check2_") == 0) {
            int index = (int)StringToInteger(StringSubstr(sparam, 7));
            ToggleCheckbox(index, false);
            return;
        }
        
        if(StringFind(sparam, "Symbol_") == 0) {
            int index = (int)StringToInteger(StringSubstr(sparam, 7));
            ChangeAllChartsSymbol(symbolList[index].name);
        }
    }
}

void ToggleCheckbox(int index, bool isFirstCheckbox) {
    if(isFirstCheckbox) {
        symbolList[index].fav1 = !symbolList[index].fav1;
        ObjectSetInteger(0, "Check1_" + IntegerToString(index), OBJPROP_BGCOLOR, 
                        symbolList[index].fav1 ? clrRed : clrWhite);
    }
    else {
        symbolList[index].fav2 = !symbolList[index].fav2;
        ObjectSetInteger(0, "Check2_" + IntegerToString(index), OBJPROP_BGCOLOR, 
                        symbolList[index].fav2 ? clrRed : clrWhite);
    }
    
    if(currentSortMode == 2) {
        SortSymbols();
        CreateSymbolList();
    }
}

void LoadMarketWatchSymbols() {
    totalSymbols = 0;
    ArrayResize(symbolList, 0);
    
    for(int i = 0; i < SymbolsTotal(true); i++) {
        string symbol = SymbolName(i, true);
        if(symbol != "") {
            ArrayResize(symbolList, totalSymbols + 1);
            symbolList[totalSymbols].name = symbol;
            symbolList[totalSymbols].fav1 = false;
            symbolList[totalSymbols].fav2 = false;
            symbolList[totalSymbols].inBuyZone = false;
            symbolList[totalSymbols].inSellZone = false;
            symbolList[totalSymbols].activeZones = "";
            ArrayResize(symbolList[totalSymbols].zones, 0);
            totalSymbols++;
        }
    }
}

void LoadFavorites() {
    int handle = FileOpen(favoritesFile, FILE_READ|FILE_TXT);
    if(handle != INVALID_HANDLE) {
        while(!FileIsEnding(handle)) {
            string line = FileReadString(handle);
            string parts[];
            StringSplit(line, ',', parts);
            if(ArraySize(parts) >= 3) {
                for(int i = 0; i < totalSymbols; i++) {
                    if(symbolList[i].name == parts[0]) {
                        symbolList[i].fav1 = (parts[1] == "1");
                        symbolList[i].fav2 = (parts[2] == "1");
                        break;
                    }
                }
            }
        }
        FileClose(handle);
    }
}

void SaveFavorites() {
    int handle = FileOpen(favoritesFile, FILE_WRITE|FILE_TXT);
    if(handle != INVALID_HANDLE) {
        for(int i = 0; i < totalSymbols; i++) {
            string line = symbolList[i].name + "," + 
                         (symbolList[i].fav1 ? "1" : "0") + "," + 
                         (symbolList[i].fav2 ? "1" : "0") + "\n";
            FileWriteString(handle, line);
        }
        FileClose(handle);
    }
}

void LoadZones() {
    string zonesFolder = "Zones";
    for(int i = 0; i < totalSymbols; i++) {
        string fileName = zonesFolder + "//" + symbolList[i].name + "_zones.txt";
        int handle = FileOpen(fileName, FILE_READ|FILE_TXT);
        if(handle != INVALID_HANDLE) {
            ArrayResize(symbolList[i].zones, 0);
            int zoneIndex = 0;
            
            while(!FileIsEnding(handle)) {
                string line = FileReadString(handle);
                string parts[];
                StringSplit(line, ',', parts);
                
                if(ArraySize(parts) >= 7) {
                    ArrayResize(symbolList[i].zones, zoneIndex + 1);
                    symbolList[i].zones[zoneIndex].name = parts[0];
                    symbolList[i].zones[zoneIndex].type = parts[1];
                    symbolList[i].zones[zoneIndex].time1 = StringToTime(parts[2]);
                    symbolList[i].zones[zoneIndex].time2 = StringToTime(parts[3]);
                    symbolList[i].zones[zoneIndex].price1 = StringToDouble(parts[4]);
                    symbolList[i].zones[zoneIndex].price2 = StringToDouble(parts[5]);
                    symbolList[i].zones[zoneIndex].timeframe = (int)StringToInteger(parts[6]);
                    zoneIndex++;
                }
            }
            FileClose(handle);
        }
    }
}

int OnCalculate(const int rates_total, const int prev_calculated, const datetime &time[],
                const double &open[], const double &high[], const double &low[],
                const double &close[], const long &tick_volume[], const long &volume[],
                const int &spread[]) {
    return(rates_total);
}