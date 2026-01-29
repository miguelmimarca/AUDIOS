//+------------------------------------------------------------------+
//|                                                     Secuencia.mq4  |
//|                                  Copyright 2024, MetaQuotes Ltd.   |
//|                                             https://www.mql4.com   |
//+------------------------------------------------------------------+

#property copyright "Copyright 2024"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#define INDICATOR_NAME "Secuencia"

// Variables globales para control de dibujo
string currentLineType = "";
bool isDrawing = false;
string tempLineName = "";

// Variables globales para manejo de coordenadas y precios
double price;
datetime time;
int window;
int bar;
double high;
double low;
double finalPrice;
color lineColor;

// Variables globales para control de tiempo
datetime lastUpdate = 0;
datetime lastProcessing = 0;

// Arrays globales
datetime intersectTime[];
double ExtMapBuffer[];

// Añadir al inicio del archivo, junto con los otros inputs
input string SaveFolderName = "Secuencia";  // Nombre de la carpeta para guardar
input string SaveFileName = "MyLines.dat";   // Nombre del archivo para guardar

struct LineProperties {
    string name;
    double price;
    datetime startTime;
    datetime endTime;
    ENUM_TIMEFRAMES timeframe;
    bool isMitigated;
    bool isHighLevel;    // Nuevo campo
    
    // Propiedades visuales
    color lineColor;
    int width;
    ENUM_LINE_STYLE style;
    bool ray;
    bool selectable;
    bool hidden;
    int zOrder;
    string tooltip;
    int timeframeFlags;
    
    void LineProperties() {  // Constructor actualizado
        name = "";
        price = 0.0;
        startTime = 0;
        endTime = 0;
        timeframe = PERIOD_CURRENT;
        isMitigated = false;
        isHighLevel = false;  // Inicialización del nuevo campo
        lineColor = clrNONE;
        width = 1;
        style = STYLE_SOLID;
        ray = false;
        selectable = true;
        hidden = false;
        zOrder = 0;
        tooltip = "";
        timeframeFlags = 0;
    }
};

// Estructura para líneas no mitigadas
struct UnmitigatedLine {
    string name;
    double price;
    ENUM_TIMEFRAMES timeframe;
    datetime startTime;
    bool initialCheckDone;
    bool isHighLevel;
    
    // Constructor por defecto requerido para arrays
    void UnmitigatedLine() {
        name = "";
        price = 0.0;
        timeframe = PERIOD_CURRENT;
        startTime = 0;
        initialCheckDone = false;
        isHighLevel = false;
    }
    
    // Constructor con parámetros
    void UnmitigatedLine(string n, double p, ENUM_TIMEFRAMES tf, datetime st, bool isHigh) {
        name = n;
        price = p;
        timeframe = tf;
        startTime = st;
        initialCheckDone = false;
        isHighLevel = isHigh;
    }
};

// Array global para líneas no mitigadas
UnmitigatedLine unmitigatedHighs[];
UnmitigatedLine unmitigatedLows[];

//+------------------------------------------------------------------+
//| Funciones de utilidad para gestión de memoria                     |
//+------------------------------------------------------------------+
void CleanupArrays() {
    Print("=== DEBUG: CleanupArrays() ===");
    Print("Antes de limpiar - Tamaño intersectTime:", ArraySize(intersectTime));
    Print("Antes de limpiar - Tamaño ExtMapBuffer:", ArraySize(ExtMapBuffer));

    ArrayFree(intersectTime);
    ArrayFree(ExtMapBuffer);
}

void ResetGlobalVariables() {
    Print("=== DEBUG: ResetGlobalVariables() ===");
    Print("Valores antes del reset:");
    Print("currentLineType:", currentLineType);
    Print("isDrawing:", isDrawing);
    Print("tempLineName:", tempLineName);

    currentLineType = "";
    isDrawing = false;
    tempLineName = "";
    price = 0.0;
    time = 0;
    window = 0;
    bar = 0;
    high = 0.0;
    low = 0.0;
    finalPrice = 0.0;
    lineColor = clrNONE;
    lastUpdate = 0;
    lastProcessing = 0;

    Print("Valores después del reset:");
    Print("currentLineType:", currentLineType);
    Print("isDrawing:", isDrawing);
    Print("tempLineName:", tempLineName);
}

//+------------------------------------------------------------------+
//| Función de inicialización del indicador                           |
//+------------------------------------------------------------------+
int OnInit() {
    if(UninitializeReason() == REASON_CHARTCHANGE) {
        string arrayKey = _Symbol + "_UnmitigatedArrays";
        
        // Restaurar HIGH lines
        int highCount = (int)GlobalVariableGet(arrayKey + "_high_count");
        ArrayResize(unmitigatedHighs, highCount);
        
        for(int h = 0; h < highCount; h++) {
            string prefixH = StringFormat("%s_high_%d_", arrayKey, h);
            unmitigatedHighs[h].price = GlobalVariableGet(prefixH + "price");
            unmitigatedHighs[h].startTime = (datetime)GlobalVariableGet(prefixH + "time");
            unmitigatedHighs[h].timeframe = (ENUM_TIMEFRAMES)GlobalVariableGet(prefixH + "tf");
            
            // Reconstruir el nombre desde los códigos ASCII
            int nameLenH = (int)GlobalVariableGet(prefixH + "name_len");
            string nameH = "";
            for(int ch = 0; ch < nameLenH; ch++) {
                ushort charCodeH = (ushort)GlobalVariableGet(prefixH + "name" + IntegerToString(ch));
                nameH = nameH + ShortToString(charCodeH);
                GlobalVariableDel(prefixH + "name" + IntegerToString(ch));
            }
            unmitigatedHighs[h].name = nameH;
            
            // Limpiar variables globales
            GlobalVariableDel(prefixH + "price");
            GlobalVariableDel(prefixH + "time");
            GlobalVariableDel(prefixH + "tf");
            GlobalVariableDel(prefixH + "name_len");
        }
        
        // Restaurar LOW lines
        int lowCount = (int)GlobalVariableGet(arrayKey + "_low_count");
        ArrayResize(unmitigatedLows, lowCount);
        
        for(int l = 0; l < lowCount; l++) {
            string prefixL = StringFormat("%s_low_%d_", arrayKey, l);
            unmitigatedLows[l].price = GlobalVariableGet(prefixL + "price");
            unmitigatedLows[l].startTime = (datetime)GlobalVariableGet(prefixL + "time");
            unmitigatedLows[l].timeframe = (ENUM_TIMEFRAMES)GlobalVariableGet(prefixL + "tf");
            
            // Reconstruir el nombre desde los códigos ASCII
            int nameLenL = (int)GlobalVariableGet(prefixL + "name_len");
            string nameL = "";
            for(int cl = 0; cl < nameLenL; cl++) {
                ushort charCodeL = (ushort)GlobalVariableGet(prefixL + "name" + IntegerToString(cl));
                nameL = nameL + ShortToString(charCodeL);
                GlobalVariableDel(prefixL + "name" + IntegerToString(cl));
            }
            unmitigatedLows[l].name = nameL;
            
            // Limpiar variables globales
            GlobalVariableDel(prefixL + "price");
            GlobalVariableDel(prefixL + "time");
            GlobalVariableDel(prefixL + "tf");
            GlobalVariableDel(prefixL + "name_len");
        }
        
        // Limpiar contadores
        GlobalVariableDel(arrayKey + "_high_count");
        GlobalVariableDel(arrayKey + "_low_count");
        
    }
    
    // Limpiar estado anterior
    CleanupArrays();
    ResetGlobalVariables();
    
    // Crear botones
    CreateButton("btnDKL", "DKL", 400, 5);
    CreateButton("btnRKL", "RKL", 435, 5);
    CreateButton("btnVTX", "VTX", 470, 5);
    CreateButton("btnLIQ", "LIQ", 505, 5);
    CreateButton("btnSAVE", "SAVE", 550, 5);
    CreateButton("btnLOAD", "LOAD", 585, 5);
    
    // Configurar chart
    ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 1);
    ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, 1);
    ChartSetInteger(0, CHART_EVENT_OBJECT_DELETE, 1);
    ChartSetInteger(0, CHART_SHOW_OBJECT_DESCR, 1);
    ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, 0);
    
    // Inicializar buffer técnico
    SetIndexBuffer(0, ExtMapBuffer);
    SetIndexStyle(0, DRAW_NONE);
    
    // Verificar líneas existentes
    int totalLines = 0;
    for(int i = ObjectsTotal(0, 0, OBJ_TREND) - 1; i >= 0; i--) {
        string objName = ObjectName(0, i, 0, OBJ_TREND);
        if(StringFind(objName, "DKL_") == 0 || 
           StringFind(objName, "RKL_") == 0 || 
           StringFind(objName, "VTX_") == 0 || 
           StringFind(objName, "LIQ_") == 0) {
            totalLines++;
        }
    }
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Obtener propiedades de la línea según el tipo                     |
//+------------------------------------------------------------------+
void GetLineProperties(string buttonType, color& outColor) {
    if(buttonType == "btnDKL") 
        outColor = clrGreen;
    else if(buttonType == "btnRKL") 
        outColor = clrOrange;
    else if(buttonType == "btnVTX")
        outColor = clrBlue;
    else if(buttonType == "btnLIQ")
        outColor = clrMagenta;
    else
        outColor = clrSkyBlue;
}

//+------------------------------------------------------------------+
//| Crear botón                                                       |
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y) {
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, 30);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, 15);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 6);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
    ObjectSetInteger(0, name, OBJPROP_STATE,  false);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);  // Borde plano
    
    // Establecer colores según el tipo de botón
    color bgColor;
    if(name == "btnDKL")
        bgColor = clrGreen;
    else if(name == "btnRKL")
        bgColor = clrOrange;
    else if(name == "btnVTX")
        bgColor = clrBlue;
    else if(name == "btnLIQ")
        bgColor = clrMagenta;
    else
        bgColor = clrGray;
        
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, bgColor);  // Color del borde igual al fondo
    
    // Ajustar color del texto para mejor visibilidad
    if(name == "btnVTX" || name == "btnDKL")
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
    else
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
}

//+------------------------------------------------------------------+
//| Obtener el minuto exacto dentro del timeframe actual              |
//+------------------------------------------------------------------+
int GetExactMinute(datetime barOpenTime, double targetPrice, bool isHighPrice) {
    ENUM_TIMEFRAMES currentTF = (ENUM_TIMEFRAMES)Period();
    datetime barStartTime = barOpenTime - (barOpenTime % PeriodSeconds(currentTF));
    int periodMinutes = PeriodSeconds(currentTF) / 60;
    
    for(int i = 0; i < periodMinutes; i++) {
        datetime minuteTime = barStartTime + (i * 60);
        int m1Bar = iBarShift(_Symbol, PERIOD_M1, minuteTime);
        
        if(isHighPrice) {
            if(iHigh(_Symbol, PERIOD_M1, m1Bar) == targetPrice) return i;
        } else {
            if(iLow(_Symbol, PERIOD_M1, m1Bar) == targetPrice) return i;
        }
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Función para encontrar el punto de intersección                   |
//+------------------------------------------------------------------+
datetime FindIntersectionTime(datetime startTime, string lineType, double priceLevel) {
    datetime currentTime = TimeCurrent();
    ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)Period();
    int startBar = iBarShift(_Symbol, tf, startTime);
    datetime localIntersectTime[];
    datetime result;
    
    
    ArrayResize(localIntersectTime, 1);
    
    bool isHighLevel = (priceLevel >= iHigh(_Symbol, tf, startBar));
    
    for(int j = startBar - 1; j >= 0; j--) {
        if(isHighLevel) {
            double currentHigh = iHigh(_Symbol, tf, j);
            if(currentHigh > priceLevel) {
                if(CopyTime(_Symbol, tf, j, 1, localIntersectTime) > 0) {
                    // Buscar el momento exacto en M1
                    result = FindExactMitigationTime(localIntersectTime[0], priceLevel, true);
                    ArrayFree(localIntersectTime);
                    return result;
                }
            }
        } else {
            double currentLow = iLow(_Symbol, tf, j);
            if(currentLow < priceLevel) {
                if(CopyTime(_Symbol, tf, j, 1, localIntersectTime) > 0) {
                    // Buscar el momento exacto en M1
                    result = FindExactMitigationTime(localIntersectTime[0], priceLevel, false);
                    ArrayFree(localIntersectTime);
                    return result;
                }
            }
        }
    }
    
    ArrayFree(localIntersectTime);
    return currentTime;
}

//+------------------------------------------------------------------+
//| Función para encontrar el punto de intersección                   |
//+------------------------------------------------------------------+
datetime FindExactMitigationTime(datetime mitigationBarTime, double priceLevel, bool isHighLevel) {
    // Obtener el inicio y fin de la vela que mitigó
    datetime barStart = mitigationBarTime;
    datetime barEnd = mitigationBarTime + PeriodSeconds((ENUM_TIMEFRAMES)Period());
    
    // Encontrar la primera vela M1 dentro del rango que mitigó el nivel
    int startBar = iBarShift(_Symbol, PERIOD_M1, barStart);
    int endBar = iBarShift(_Symbol, PERIOD_M1, barEnd);
    
    for(int i = startBar; i >= endBar; i--) {
        if(isHighLevel) {
            if(iHigh(_Symbol, PERIOD_M1, i) > priceLevel) {
                return iTime(_Symbol, PERIOD_M1, i);
            }
        } else {
            if(iLow(_Symbol, PERIOD_M1, i) < priceLevel) {
                return iTime(_Symbol, PERIOD_M1, i);
            }
        }
    }
    
    return mitigationBarTime; // Si no encontramos el momento exacto, retornamos el inicio de la vela
}

//+------------------------------------------------------------------+
//| Funciones de gestión de líneas no mitigadas                       |
//+------------------------------------------------------------------+
bool AddUnmitigatedLine(string name, double linePrice, datetime startTime, bool isHighLevel, ENUM_TIMEFRAMES originalTF) {
    if(name == "" || startTime <= 0) return false;
    
    int size;
    int i;
    int j;
    UnmitigatedLine newLine;
    newLine.name = name;
    newLine.price = linePrice;
    newLine.startTime = startTime;
    newLine.isHighLevel = isHighLevel;
    newLine.timeframe = originalTF;
    
    if(isHighLevel) {
        size = ArraySize(unmitigatedHighs);
        if(!ArrayResize(unmitigatedHighs, size + 1)) return false;
        
        // Encontrar posición para mantener orden ascendente por precio
        for(i = 0; i < size; i++) {
            if(linePrice < unmitigatedHighs[i].price) break;
        }
        
        // Desplazar elementos para hacer espacio
        for(j = size; j > i; j--) {
            unmitigatedHighs[j] = unmitigatedHighs[j-1];
        }
        
        // Insertar nueva línea y extenderla hasta la vela actual M1
        unmitigatedHighs[i] = newLine;
        ObjectMove(0, name, 1, iTime(_Symbol, PERIOD_M1, 0), linePrice);
        
        // Mantener la máscara de visibilidad original
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, GetTimeframeVisibilityMask(newLine.timeframe));
        
    } else {
        size = ArraySize(unmitigatedLows);
        if(!ArrayResize(unmitigatedLows, size + 1)) return false;
        
        // Encontrar posición para mantener orden descendente por precio
        for(i = 0; i < size; i++) {
            if(linePrice > unmitigatedLows[i].price) break;
        }
        
        // Desplazar elementos para hacer espacio
        for(j = size; j > i; j--) {
            unmitigatedLows[j] = unmitigatedLows[j-1];
        }
        
        // Insertar nueva línea y extenderla hasta la vela actual M1
        unmitigatedLows[i] = newLine;
        ObjectMove(0, name, 1, iTime(_Symbol, PERIOD_M1, 0), linePrice);
        
        // Mantener la máscara de visibilidad original
        ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, GetTimeframeVisibilityMask(newLine.timeframe));
    }
    
    
    return true;
}


//+------------------------------------------------------------------+
//| Funciones de sincronización entre charts                          |
//+------------------------------------------------------------------+
void CopyObjectToOtherCharts(string objectName, datetime time1, double price1, datetime time2, int visibility) {
    long chartId = ChartFirst();
    
    while(chartId >= 0) {
        
        if(ChartSymbol(chartId) == _Symbol && chartId != ChartID()) {
            
            
            if(ObjectCreate(chartId, objectName, OBJ_TREND, 0, time1, price1, time2, price1)) {
                // Copiar propiedades básicas
                ObjectSetInteger(chartId, objectName, OBJPROP_COLOR, ObjectGetInteger(0, objectName, OBJPROP_COLOR));
                ObjectSetInteger(chartId, objectName, OBJPROP_WIDTH, ObjectGetInteger(0, objectName, OBJPROP_WIDTH));
                ObjectSetInteger(chartId, objectName, OBJPROP_RAY, ObjectGetInteger(0, objectName, OBJPROP_RAY));
                ObjectSetInteger(chartId, objectName, OBJPROP_SELECTABLE, true);
                ObjectSetInteger(chartId, objectName, OBJPROP_HIDDEN, false);
                ObjectSetInteger(chartId, objectName, OBJPROP_ZORDER, 0);
                ObjectSetInteger(chartId, objectName, OBJPROP_TIMEFRAMES, visibility);
                
                // Obtener los valores originales
                string originalTooltip = ObjectGetString(0, objectName, OBJPROP_TOOLTIP);
                string originalLevelText = ObjectGetString(0, objectName, OBJPROP_LEVELTEXT, 0);
                
                // Copiar el tooltip y el timeframe original exactamente igual que en el chart original
                ObjectSetString(chartId, objectName, OBJPROP_TOOLTIP, originalTooltip);
                ObjectSetString(chartId, objectName, OBJPROP_LEVELTEXT, 0, originalLevelText);
                
                
                ChartRedraw(chartId);
            }
        }
        
        long prevId = chartId;
        chartId = ChartNext(chartId);
    }
}

void UpdateObjectInOtherCharts(string objectName, datetime time1, double price1, datetime time2, double price2) {
    // Obtener los valores originales antes de actualizar
    string originalTooltip = ObjectGetString(0, objectName, OBJPROP_TOOLTIP);
    string originalLevelText = ObjectGetString(0, objectName, OBJPROP_LEVELTEXT, 0);
    
    long chartId = ChartFirst();
    while(chartId != -1) {
        if(ChartSymbol(chartId) == _Symbol && chartId != ChartID()) {
            if(ObjectFind(chartId, objectName) >= 0) {
                // Actualizar posición y precio
                ObjectSetInteger(chartId, objectName, OBJPROP_TIME, 0, time1);
                ObjectSetInteger(chartId, objectName, OBJPROP_TIME, 1, time2);
                ObjectSetDouble(chartId, objectName, OBJPROP_PRICE, 0, price1);
                ObjectSetDouble(chartId, objectName, OBJPROP_PRICE, 1, price2);
                
                // Mantener el tooltip y leveltext original
                ObjectSetString(chartId, objectName, OBJPROP_TOOLTIP, originalTooltip);
                ObjectSetString(chartId, objectName, OBJPROP_LEVELTEXT, 0, originalLevelText);
                
                ChartRedraw(chartId);
            } else {
                // Si el objeto no existe en este chart, crearlo
                if(ObjectCreate(chartId, objectName, OBJ_TREND, 0, time1, price1, time2, price2)) {
                    // Copiar todas las propiedades
                    ObjectSetInteger(chartId, objectName, OBJPROP_COLOR, ObjectGetInteger(0, objectName, OBJPROP_COLOR));
                    ObjectSetInteger(chartId, objectName, OBJPROP_WIDTH, ObjectGetInteger(0, objectName, OBJPROP_WIDTH));
                    ObjectSetInteger(chartId, objectName, OBJPROP_RAY, ObjectGetInteger(0, objectName, OBJPROP_RAY));
                    ObjectSetInteger(chartId, objectName, OBJPROP_SELECTABLE, true);
                    ObjectSetInteger(chartId, objectName, OBJPROP_HIDDEN, false);
                    ObjectSetInteger(chartId, objectName, OBJPROP_ZORDER, 0);
                    ObjectSetInteger(chartId, objectName, OBJPROP_TIMEFRAMES, GetTimeframeVisibilityMask((ENUM_TIMEFRAMES)Period()));
                    
                    // Establecer tooltip y timeframe original
                    ObjectSetString(chartId, objectName, OBJPROP_TOOLTIP, originalTooltip);
                    ObjectSetString(chartId, objectName, OBJPROP_LEVELTEXT, 0, originalLevelText);
                    
                    ChartRedraw(chartId);
                }
            }
        }
        chartId = ChartNext(chartId);
    }
}

void DeleteObjectFromOtherCharts(string objectName) {
    long chartId = ChartFirst();
    while(chartId != -1) {
        if(ChartSymbol(chartId) == _Symbol && chartId != ChartID()) {
            if(ObjectFind(chartId, objectName) >= 0) {
                ObjectDelete(chartId, objectName);
                ChartRedraw(chartId);
            }
        }
        chartId = ChartNext(chartId);
    }
}

//+------------------------------------------------------------------+
//| Obtener máscara de visibilidad para timeframes                    |
//+------------------------------------------------------------------+
int GetTimeframeVisibilityMask(ENUM_TIMEFRAMES current_tf) {
    int visibility = 0;
    
    switch(current_tf) {
        case PERIOD_MN1:
            visibility |= OBJ_PERIOD_MN1;
            // fall through
        case PERIOD_W1:
            visibility |= OBJ_PERIOD_W1;
            // fall through
        case PERIOD_D1:
            visibility |= OBJ_PERIOD_D1;
            // fall through
        case PERIOD_H4:
            visibility |= OBJ_PERIOD_H4;
            // fall through
        case PERIOD_H1:
            visibility |= OBJ_PERIOD_H1;
            // fall through
        case PERIOD_M30:
            visibility |= OBJ_PERIOD_M30;
            // fall through
        case PERIOD_M15:
            visibility |= OBJ_PERIOD_M15;
            // fall through
        case PERIOD_M5:
            visibility |= OBJ_PERIOD_M5;
            // fall through
        case PERIOD_M1:
            visibility |= OBJ_PERIOD_M1;
            break;
        default:
            visibility = OBJ_ALL_PERIODS;
            break;
    }
    
    return visibility;
}

//+------------------------------------------------------------------+
//| Función de cálculo del indicador                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &timeArray[],
                const double &open[],
                const double &highPrice[],
                const double &lowPrice[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    static datetime lastM1Bar = 0;
    datetime currentM1Bar = iTime(_Symbol, PERIOD_M1, 0);
    
    if(currentM1Bar != lastM1Bar) {
        CheckMitigatedLines();  // Verificar mitigación antes de actualizar
        lastM1Bar = currentM1Bar;
        UpdateUnmitigatedLines();
    }
    
    ExtMapBuffer[0] = close[0];
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Obtener el siguiente número disponible para el tipo de línea      |
//+------------------------------------------------------------------+
int GetNextLineNumber(string buttonType) {
    string prefix = StringSubstr(buttonType, 3) + "_";
    int maxNumber = 0;
    
    for(int i = ObjectsTotal(0, 0, OBJ_TREND) - 1; i >= 0; i--) {
        string objName = ObjectName(0, i, 0, OBJ_TREND);
        
        if(StringFind(objName, prefix) == 0) {
            string numPart = StringSubstr(objName, StringLen(prefix));
            int currentNumber = (int)StringToInteger(numPart);
            if(currentNumber > maxNumber) maxNumber = currentNumber;
        }
    }
    
    return maxNumber + 1;
}

//+------------------------------------------------------------------+
//| Función de eventos del gráfico                                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                 const long &lparam,
                 const double &dparam,
                 const string &sparam)
{
    static bool buttonWasClicked = false;
    datetime adjustedTime;
    
    if(id == CHARTEVENT_OBJECT_CLICK) {
        if(sparam == "btnDKL" || sparam == "btnRKL" || 
           sparam == "btnVTX" || sparam == "btnLIQ") {
            currentLineType = sparam;
            isDrawing = true;
            buttonWasClicked = true;
            return;
        }
        else if(sparam == "btnSAVE") {
            SaveLines();
            return;
        }
        else if(sparam == "btnLOAD") {
            LoadLines();
            return;
        }
    }

    if(id == CHARTEVENT_CLICK && buttonWasClicked) {
        buttonWasClicked = false;
        return;
    }

    // Manejo del movimiento del mouse durante el dibujo
    if(id == CHARTEVENT_MOUSE_MOVE && isDrawing) {
        if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, window, time, price)) {
            bar = iBarShift(_Symbol, (ENUM_TIMEFRAMES)Period(), time);
            high = iHigh(_Symbol, (ENUM_TIMEFRAMES)Period(), bar);
            low = iLow(_Symbol, (ENUM_TIMEFRAMES)Period(), bar);
            finalPrice = (price > (high + low)/2) ? high : low;
            
            if(tempLineName != "") 
                ObjectDelete(0, tempLineName);
            
            tempLineName = "temp_line";
            
            datetime timeEnd = time + PeriodSeconds((ENUM_TIMEFRAMES)Period());
            adjustedTime = time - (time % PeriodSeconds((ENUM_TIMEFRAMES)Period())) + 
                          (GetExactMinute(time, finalPrice, finalPrice == high) * 60);
            
            if(ObjectCreate(0, tempLineName, OBJ_TREND, 0, adjustedTime, finalPrice, timeEnd, finalPrice)) {
                GetLineProperties(currentLineType, lineColor);
                ObjectSetInteger(0, tempLineName, OBJPROP_COLOR, lineColor);
                ObjectSetInteger(0, tempLineName, OBJPROP_WIDTH, 2);
                ObjectSetInteger(0, tempLineName, OBJPROP_RAY, false);
                ObjectSetInteger(0, tempLineName, OBJPROP_SELECTABLE, false);
                ChartRedraw();
            }
        }
    }

    // Manejo del click final para crear la línea
    if(id == CHARTEVENT_CLICK && isDrawing) {
        if(ChartXYToTimePrice(0, (int)lparam, (int)dparam, window, time, price)) {
            bar = iBarShift(_Symbol, (ENUM_TIMEFRAMES)Period(), time);
            high = iHigh(_Symbol, (ENUM_TIMEFRAMES)Period(), bar);
            low = iLow(_Symbol, (ENUM_TIMEFRAMES)Period(), bar);
            finalPrice = (price > (high + low)/2) ? high : low;
            
            adjustedTime = time - (time % PeriodSeconds((ENUM_TIMEFRAMES)Period())) + 
                          (GetExactMinute(time, finalPrice, finalPrice == high) * 60);
            
            // Simplificación del nombre de la línea
            string finalName = StringSubstr(currentLineType, 3) + "_" + 
                              IntegerToString(GetNextLineNumber(currentLineType));
            
            if(ObjectCreate(0, finalName, OBJ_TREND, 0, adjustedTime, finalPrice, adjustedTime, finalPrice)) {
                datetime endTime = FindIntersectionTime(adjustedTime, currentLineType, finalPrice);
                
                if(endTime == TimeCurrent()) {  // Si no está mitigada
                    datetime m1Time = iTime(_Symbol, PERIOD_M1, 0);
                    if(AddUnmitigatedLine(finalName, finalPrice, adjustedTime, finalPrice == high, (ENUM_TIMEFRAMES)Period())) {
                        ObjectMove(0, finalName, 1, m1Time, finalPrice);
                    }
                } else {
                    ObjectMove(0, finalName, 1, endTime, finalPrice);
                }
                
                GetLineProperties(currentLineType, lineColor);
                ObjectSetInteger(0, finalName, OBJPROP_COLOR, lineColor);
                ObjectSetInteger(0, finalName, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, finalName, OBJPROP_RAY, false);
                ObjectSetInteger(0, finalName, OBJPROP_SELECTABLE, true);
                ObjectSetInteger(0, finalName, OBJPROP_TIMEFRAMES, GetTimeframeVisibilityMask((ENUM_TIMEFRAMES)Period()));
                
                // Extraer el tipo de línea del nombre (DKL, RKL, VTX, LIQ)
                string lineType = StringSubstr(finalName, 0, 3);
                string tfStr;
                switch(Period()) {
                    case PERIOD_M1:  tfStr = "M1"; break;
                    case PERIOD_M5:  tfStr = "M5"; break;
                    case PERIOD_M15: tfStr = "M15"; break;
                    case PERIOD_M30: tfStr = "M30"; break;
                    case PERIOD_H1:  tfStr = "H1"; break;
                    case PERIOD_H4:  tfStr = "H4"; break;
                    case PERIOD_D1:  tfStr = "D1"; break;
                    case PERIOD_W1:  tfStr = "W1"; break;
                    case PERIOD_MN1: tfStr = "MN1"; break;
                    default:         tfStr = "TF" + IntegerToString(Period());
                }

                // Guardar la información solo en el tooltip
                string tooltipText = lineType + " " + tfStr;
                ObjectSetString(0, finalName, OBJPROP_TOOLTIP, tooltipText);
                ObjectSetString(0, finalName, OBJPROP_LEVELTEXT, 0, tfStr);

                
                CopyObjectToOtherCharts(finalName, adjustedTime, finalPrice, 
                                       (endTime == TimeCurrent() ? m1Time : endTime), 
                                       GetTimeframeVisibilityMask((ENUM_TIMEFRAMES)Period()));
                
                
                ChartRedraw();
            }
            
            if(tempLineName != "")
                ObjectDelete(0, tempLineName);
            
            isDrawing = false;
            tempLineName = "";
        }
    }
    
    // Manejo de arrastre y cambios en objetos
    if(id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_CHANGE) {
        if(StringFind(sparam, "DKL_") == 0 || 
           StringFind(sparam, "RKL_") == 0 || 
           StringFind(sparam, "VTX_") == 0 || 
           StringFind(sparam, "LIQ_") == 0) {
            datetime time1 = (datetime)ObjectGetInteger(0, sparam, OBJPROP_TIME, 0);
            datetime time2 = (datetime)ObjectGetInteger(0, sparam, OBJPROP_TIME, 1);
            double price1 = ObjectGetDouble(0, sparam, OBJPROP_PRICE, 0);
            double price2 = ObjectGetDouble(0, sparam, OBJPROP_PRICE, 1);
            
            UpdateObjectInOtherCharts(sparam, time1, price1, time2, price2);
        }
    }
    
    // Manejo de eliminación de objetos
    if(id == CHARTEVENT_OBJECT_DELETE) {
        if(StringFind(sparam, "RKL_") == 0 || 
           StringFind(sparam, "DKL_") == 0 || 
           StringFind(sparam, "VTX_") == 0 || 
           StringFind(sparam, "LIQ_") == 0) {
            
            Print("=== DEBUG: Borrando línea manualmente ===");
            Print("Nombre de línea a borrar:", sparam);
            
            // Primero eliminar en el gráfico actual
            ObjectDelete(0, sparam);
        
            // Luego eliminar en los otros gráficos
            DeleteObjectFromOtherCharts(sparam);
            
            // Limpiar de unmitigatedHighs
            for(int h = ArraySize(unmitigatedHighs) - 1; h >= 0; h--) {
                if(unmitigatedHighs[h].name == sparam) {
                    Print("Encontrada en unmitigatedHighs[", h, "]");
                    ArrayRemoveElement(unmitigatedHighs, h);
                    Print("Línea eliminada de unmitigatedHighs");
                    break;
                }
            }
            
            // Limpiar de unmitigatedLows
            for(int l = ArraySize(unmitigatedLows) - 1; l >= 0; l--) {
                if(unmitigatedLows[l].name == sparam) {
                    Print("Encontrada en unmitigatedLows[", l, "]");
                    ArrayRemoveElement(unmitigatedLows, l);
                    Print("Línea eliminada de unmitigatedLows");
                    break;
                }
            }
            
            Print("=== Fin del borrado manual ===");
        }
    }
}

//+------------------------------------------------------------------+
//| Función de desinicialización                                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    
    if(reason == REASON_CHARTCHANGE) {
        string arrayKey = _Symbol + "_UnmitigatedArrays";
        
        
        // Guardar número de líneas
        GlobalVariableSet(arrayKey + "_high_count", ArraySize(unmitigatedHighs));
        GlobalVariableSet(arrayKey + "_low_count", ArraySize(unmitigatedLows));
        
        // Guardar HIGH lines
        for(int h = 0; h < ArraySize(unmitigatedHighs); h++) {
            string prefixH = StringFormat("%s_high_%d_", arrayKey, h);
            GlobalVariableSet(prefixH + "price", unmitigatedHighs[h].price);
            GlobalVariableSet(prefixH + "time", unmitigatedHighs[h].startTime);
            GlobalVariableSet(prefixH + "tf", unmitigatedHighs[h].timeframe);
            
            // Convertir el nombre a un número usando el código ASCII de cada carácter
            for(int ch = 0; ch < StringLen(unmitigatedHighs[h].name); ch++) {
                GlobalVariableSet(prefixH + "name" + IntegerToString(ch), 
                                StringGetChar(unmitigatedHighs[h].name, ch));
            }
            GlobalVariableSet(prefixH + "name_len", StringLen(unmitigatedHighs[h].name));
        }
        
        // Guardar LOW lines
        for(int l = 0; l < ArraySize(unmitigatedLows); l++) {
            string prefixL = StringFormat("%s_low_%d_", arrayKey, l);
            GlobalVariableSet(prefixL + "price", unmitigatedLows[l].price);
            GlobalVariableSet(prefixL + "time", unmitigatedLows[l].startTime);
            GlobalVariableSet(prefixL + "tf", unmitigatedLows[l].timeframe);
            
            // Convertir el nombre a un número usando el código ASCII de cada carácter
            for(int cl = 0; cl < StringLen(unmitigatedLows[l].name); cl++) {
                GlobalVariableSet(prefixL + "name" + IntegerToString(cl), 
                                StringGetChar(unmitigatedLows[l].name, cl));
            }
            GlobalVariableSet(prefixL + "name_len", StringLen(unmitigatedLows[l].name));
        }
    } else {
        CleanupArrays();
        ResetGlobalVariables();
    }
    
    // Eliminar botones
    ObjectDelete(0, "btnDKL");
    ObjectDelete(0, "btnRKL");
    ObjectDelete(0, "btnVTX");
    ObjectDelete(0, "btnLIQ");
    ObjectDelete(0, "btnSAVE");
    ObjectDelete(0, "btnLOAD");
    
    if(tempLineName != "") 
        ObjectDelete(0, tempLineName);
    
    // Asegurar que se libera toda la memoria temporal
    ArrayFree(intersectTime);
    ArrayFree(ExtMapBuffer);
}




void ArrayRemoveElement(UnmitigatedLine &array[], int index) {
    int size = ArraySize(array);
    for(int i = index; i < size - 1; i++) {
        array[i] = array[i + 1];
    }
    ArrayResize(array, size - 1);
}

void UpdateUnmitigatedLines() {
    datetime m1Time = iTime(_Symbol, PERIOD_M1, 0);
    
    
    // Actualizar líneas HIGH no mitigadas
    for(int h = 0; h < ArraySize(unmitigatedHighs); h++) {
        
        ObjectMove(0, unmitigatedHighs[h].name, 1, m1Time, unmitigatedHighs[h].price);
        UpdateObjectInOtherCharts(unmitigatedHighs[h].name, 
                                unmitigatedHighs[h].startTime, 
                                unmitigatedHighs[h].price, 
                                m1Time, 
                                unmitigatedHighs[h].price);
    }
    
    // Actualizar líneas LOW no mitigadas
    for(int l = 0; l < ArraySize(unmitigatedLows); l++) {
        
        ObjectMove(0, unmitigatedLows[l].name, 1, m1Time, unmitigatedLows[l].price);
        UpdateObjectInOtherCharts(unmitigatedLows[l].name, 
                                unmitigatedLows[l].startTime, 
                                unmitigatedLows[l].price, 
                                m1Time, 
                                unmitigatedLows[l].price);
    }
    
    ChartRedraw();
}

void CheckMitigatedLines() {
    double m1High = iHigh(_Symbol, PERIOD_M1, 1);  // Vela recién cerrada
    double m1Low = iLow(_Symbol, PERIOD_M1, 1);
    datetime m1Time = iTime(_Symbol, PERIOD_M1, 1);
    
    // Verificar líneas HIGH (ordenadas de menor a mayor precio)
    for(int h = 0; h < ArraySize(unmitigatedHighs); h++) {
        if(m1High <= unmitigatedHighs[h].price) {
            break;  // Si no mitigó la más baja, no mitigará las más altas
        }
        
        // Fijar la línea en el punto de mitigación
        ObjectMove(0, unmitigatedHighs[h].name, 1, m1Time, unmitigatedHighs[h].price);
        UpdateObjectInOtherCharts(unmitigatedHighs[h].name, 
                                unmitigatedHighs[h].startTime, 
                                unmitigatedHighs[h].price, 
                                m1Time, 
                                unmitigatedHighs[h].price);
        
        // Marcar para remover
        unmitigatedHighs[h].name = "";  // Marcamos para remover
    }
    
    // Verificar líneas LOW (ordenadas de mayor a menor precio)
    for(int l = 0; l < ArraySize(unmitigatedLows); l++) {
        if(m1Low >= unmitigatedLows[l].price) {
            break;  // Si no mitigó la más alta, no mitigará las más bajas
        }
        
        // Fijar la línea en el punto de mitigación
        ObjectMove(0, unmitigatedLows[l].name, 1, m1Time, unmitigatedLows[l].price);
        UpdateObjectInOtherCharts(unmitigatedLows[l].name, 
                                unmitigatedLows[l].startTime, 
                                unmitigatedLows[l].price, 
                                m1Time, 
                                unmitigatedLows[l].price);
        
        // Marcar para remover
        unmitigatedLows[l].name = "";  // Marcamos para remover
    }
    
    // Remover las líneas marcadas
    RemoveMarkedLines();
    
    
}

// Nueva función para remover líneas marcadas
void RemoveMarkedLines() {
    // Remover líneas HIGH marcadas
    int highSize = ArraySize(unmitigatedHighs);
    for(int h = highSize - 1; h >= 0; h--) {
        if(unmitigatedHighs[h].name == "") {
            ArrayRemoveElement(unmitigatedHighs, h);
        }
    }
    
    // Remover líneas LOW marcadas
    int lowSize = ArraySize(unmitigatedLows);
    for(int l = lowSize - 1; l >= 0; l--) {
        if(unmitigatedLows[l].name == "") {
            ArrayRemoveElement(unmitigatedLows, l);
        }
    }
}

bool ValidatePrice(double priceValue) {
    if(priceValue <= 0) return false;
    if(priceValue > 999999) return false;  // Un límite razonable genérico
    return true;
}

bool ValidateObjectCreation(string name, datetime timeValue) {
    if(ObjectFind(0, name) >= 0) {
        return false;
    }
    
    if(timeValue <= 0 || timeValue > TimeCurrent() + PERIOD_MN1 * 60) {
        return false;
    }
    
    return true;
}

// Reemplazar la función SaveLines() existente
void SaveLines() {
    // Crear carpeta si no existe
    FolderCreate(SaveFolderName);
    
    // Construir ruta completa
    string filePath = SaveFolderName + "\\" + SaveFileName;
    int fileHandle = FileOpen(filePath, FILE_WRITE|FILE_TXT|FILE_ANSI);
    
    if(fileHandle != INVALID_HANDLE) {
        LineProperties lines[];
        int totalLines = 0;
        int mitigatedCount = 0;
        int unmitigatedCount = 0;
        
        // Recolectar todas las líneas
        for(int obj_i = ObjectsTotal(0, 0, OBJ_TREND) - 1; obj_i >= 0; obj_i--) {
            string objName = ObjectName(0, obj_i, 0, OBJ_TREND);
            
            if(StringFind(objName, "DKL_") == 0 || 
               StringFind(objName, "RKL_") == 0 || 
               StringFind(objName, "VTX_") == 0 || 
               StringFind(objName, "LIQ_") == 0) {
                
                ArrayResize(lines, totalLines + 1);
                lines[totalLines].name = objName;
                lines[totalLines].price = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
                lines[totalLines].startTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
                lines[totalLines].endTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 1);
                lines[totalLines].timeframe = StringToTimeframe(ObjectGetString(0, objName, OBJPROP_TOOLTIP));
                
                // Determinar si es high o low level
                int startBar = iBarShift(_Symbol, lines[totalLines].timeframe, lines[totalLines].startTime);
                double barHigh = iHigh(_Symbol, lines[totalLines].timeframe, startBar);
                lines[totalLines].isHighLevel = (lines[totalLines].price >= barHigh);
                
                // Determinar si está mitigada
                lines[totalLines].isMitigated = (lines[totalLines].endTime != iTime(_Symbol, PERIOD_M1, 0));
                
                // Obtener propiedades visuales
                lines[totalLines].lineColor = (color)ObjectGetInteger(0, objName, OBJPROP_COLOR);
                lines[totalLines].width = (int)ObjectGetInteger(0, objName, OBJPROP_WIDTH);
                lines[totalLines].style = (ENUM_LINE_STYLE)ObjectGetInteger(0, objName, OBJPROP_STYLE);
                lines[totalLines].ray = ObjectGetInteger(0, objName, OBJPROP_RAY);
                lines[totalLines].selectable = ObjectGetInteger(0, objName, OBJPROP_SELECTABLE);
                lines[totalLines].hidden = ObjectGetInteger(0, objName, OBJPROP_HIDDEN);
                lines[totalLines].zOrder = (int)ObjectGetInteger(0, objName, OBJPROP_ZORDER);
                lines[totalLines].tooltip = ObjectGetString(0, objName, OBJPROP_TOOLTIP);
                lines[totalLines].timeframeFlags = (int)ObjectGetInteger(0, objName, OBJPROP_TIMEFRAMES);
                
                if(lines[totalLines].isMitigated) mitigatedCount++;
                else unmitigatedCount++;
                
                totalLines++;
            }
        }
        
        // Escribir líneas no mitigadas
        FileWrite(fileHandle, "[UnmitigatedLines]");
        FileWrite(fileHandle, "Count=" + IntegerToString(unmitigatedCount));
        
        for(int write_i = 0; write_i < totalLines; write_i++) {
            if(!lines[write_i].isMitigated) {
                WriteLineProperties(fileHandle, lines[write_i]);
            }
        }
        
        // Escribir líneas mitigadas
        FileWrite(fileHandle, "[MitigatedLines]");
        FileWrite(fileHandle, "Count=" + IntegerToString(mitigatedCount));
        
        for(int write_j = 0; write_j < totalLines; write_j++) {
            if(lines[write_j].isMitigated) {
                WriteLineProperties(fileHandle, lines[write_j]);
            }
        }
        
        FileClose(fileHandle);
        ArrayFree(lines);
        MessageBox("Líneas guardadas en MQL4/Files/" + filePath, "Guardado exitoso", MB_OK);
    } else {
        MessageBox("Error al guardar el archivo: " + filePath + "\nError: " + IntegerToString(GetLastError()), 
                  "Error", MB_ICONERROR|MB_OK);
    }
}

// Reemplazar la función LoadLines() existente
void LoadLines() {
    string filePath = SaveFolderName + "\\" + SaveFileName;
    Print("Intentando cargar archivo: ", filePath);  // Añadir este Print para debug
    
    int fileHandle = FileOpen(filePath, FILE_READ|FILE_TXT|FILE_ANSI);
    
    if(fileHandle != INVALID_HANDLE) {
        Print("Archivo abierto correctamente");  // Añadir este Print para debug
        // Limpiar líneas existentes en TODOS los gráficos
        long chartID = ChartFirst();
        while(chartID >= 0) {
            if(ChartSymbol(chartID) == Symbol()) {
                for(int i = ObjectsTotal(chartID, 0, OBJ_TREND) - 1; i >= 0; i--) {
                    string objName = ObjectName(chartID, i, 0, OBJ_TREND);
                    if(StringFind(objName, "DKL_") == 0 || 
                       StringFind(objName, "RKL_") == 0 || 
                       StringFind(objName, "VTX_") == 0 || 
                       StringFind(objName, "LIQ_") == 0) {
                        ObjectDelete(chartID, objName);
                    }
                }
            }
            chartID = ChartNext(chartID);
        }
        
        // Limpiar arrays de líneas no mitigadas
        ArrayFree(unmitigatedHighs);
        ArrayFree(unmitigatedLows);
        
        string currentLine;
        LineProperties line;
        
        while(!FileIsEnding(fileHandle)) {
            currentLine = FileReadString(fileHandle);
            
            if(currentLine == "[Line]") {
                // Leer propiedades
                while(!FileIsEnding(fileHandle)) {
                    string property = FileReadString(fileHandle);
                    if(property == "") break;  // Línea vacía marca el fin de las propiedades
                    
                    string key = StringSubstr(property, 0, StringFind(property, "="));
                    string value = StringSubstr(property, StringFind(property, "=") + 1);
                    
                    if(key == "Name") line.name = value;
                    else if(key == "Price") line.price = StringToDouble(value);
                    else if(key == "StartTime") line.startTime = StringToTime(value);
                    else if(key == "EndTime") line.endTime = StringToTime(value);
                    else if(key == "Timeframe") line.timeframe = (ENUM_TIMEFRAMES)StringToInteger(value);
                    else if(key == "IsHighLevel") line.isHighLevel = (value == "true");
                    else if(key == "IsMitigated") line.isMitigated = (value == "true");
                    else if(key == "Color") line.lineColor = (color)StringToInteger(value);
                    else if(key == "Width") line.width = StringToInteger(value);
                    else if(key == "Style") line.style = (ENUM_LINE_STYLE)StringToInteger(value);
                    else if(key == "Ray") line.ray = (value == "true");
                    else if(key == "Selectable") line.selectable = (value == "true");
                    else if(key == "Hidden") line.hidden = (value == "true");
                    else if(key == "ZOrder") line.zOrder = StringToInteger(value);
                    else if(key == "Tooltip") line.tooltip = value;
                    else if(key == "TimeframeFlags") line.timeframeFlags = StringToInteger(value);
                }
                
                // Crear la línea en TODOS los gráficos
                chartID = ChartFirst();
                while(chartID >= 0) {
                    if(ChartSymbol(chartID) == Symbol()) {
                        if(ObjectCreate(chartID, line.name, OBJ_TREND, 0, line.startTime, line.price, 
                           line.isMitigated ? line.endTime : iTime(_Symbol, PERIOD_M1, 0), line.price)) {
                            
                            // Establecer propiedades visuales
                            ObjectSetInteger(chartID, line.name, OBJPROP_COLOR, line.lineColor);
                            ObjectSetInteger(chartID, line.name, OBJPROP_WIDTH, line.width);
                            ObjectSetInteger(chartID, line.name, OBJPROP_STYLE, line.style);
                            ObjectSetInteger(chartID, line.name, OBJPROP_RAY, line.ray);
                            ObjectSetInteger(chartID, line.name, OBJPROP_SELECTABLE, line.selectable);
                            ObjectSetInteger(chartID, line.name, OBJPROP_HIDDEN, line.hidden);
                            ObjectSetInteger(chartID, line.name, OBJPROP_ZORDER, line.zOrder);
                            ObjectSetString(chartID, line.name, OBJPROP_TOOLTIP, line.tooltip);
                            ObjectSetInteger(chartID, line.name, OBJPROP_TIMEFRAMES, line.timeframeFlags);
                        }
                    }
                    chartID = ChartNext(chartID);
                }
                
                // Si no está mitigada, añadirla al array correspondiente
                if(!line.isMitigated) {
                    AddUnmitigatedLine(line.name, line.price, line.startTime, 
                                     line.isHighLevel, line.timeframe);
                }
            }
        }
        
        FileClose(fileHandle);
        
        // Redibujar TODOS los gráficos
        chartID = ChartFirst();
        while(chartID >= 0) {
            if(ChartSymbol(chartID) == Symbol()) {
                ChartRedraw(chartID);
            }
            chartID = ChartNext(chartID);
        }
    } else {
        Print("Error al abrir archivo: ", GetLastError());  // Añadir este Print para debug
        MessageBox("Error al cargar el archivo: " + filePath + "\nError: " + IntegerToString(GetLastError()), 
                  "Error", MB_ICONERROR|MB_OK);
    }
}

// Función auxiliar para escribir las propiedades de una línea
void WriteLineProperties(int fileHandle, LineProperties &line) {
    FileWrite(fileHandle, "[Line]");
    FileWrite(fileHandle, "Name=" + line.name);
    FileWrite(fileHandle, "Price=" + DoubleToString(line.price, _Digits));
    FileWrite(fileHandle, "StartTime=" + TimeToString(line.startTime, TIME_DATE|TIME_MINUTES));
    FileWrite(fileHandle, "Timeframe=" + IntegerToString(line.timeframe));
    FileWrite(fileHandle, "IsHighLevel=" + (line.isHighLevel ? "true" : "false"));
    
    if(line.isMitigated) {
        FileWrite(fileHandle, "EndTime=" + TimeToString(line.endTime, TIME_DATE|TIME_MINUTES));
    }
    
    FileWrite(fileHandle, "IsMitigated=" + (line.isMitigated ? "true" : "false"));
    FileWrite(fileHandle, "Color=" + IntegerToString(line.lineColor));
    FileWrite(fileHandle, "Width=" + IntegerToString(line.width));
    FileWrite(fileHandle, "Style=" + IntegerToString(line.style));
    FileWrite(fileHandle, "Ray=" + (line.ray ? "true" : "false"));
    FileWrite(fileHandle, "Selectable=" + (line.selectable ? "true" : "false"));
    FileWrite(fileHandle, "Hidden=" + (line.hidden ? "true" : "false"));
    FileWrite(fileHandle, "ZOrder=" + IntegerToString(line.zOrder));
    FileWrite(fileHandle, "Tooltip=" + line.tooltip);
    FileWrite(fileHandle, "TimeframeFlags=" + IntegerToString(line.timeframeFlags));
    
    FileWrite(fileHandle, "");
}

// Modificar la función existente StringToTimeframe
ENUM_TIMEFRAMES StringToTimeframe(string tooltip) {
    // Extraer el timeframe del tooltip (ejemplo: "LIQ M15" -> "M15")
    string tfPart = "";
    int spacePos = StringFind(tooltip, " ");
    if(spacePos >= 0) {
        tfPart = StringSubstr(tooltip, spacePos + 1);
    }
    
    // Convertir el string del timeframe a ENUM_TIMEFRAMES
    if(tfPart == "M1") return PERIOD_M1;
    if(tfPart == "M5") return PERIOD_M5;
    if(tfPart == "M15") return PERIOD_M15;
    if(tfPart == "M30") return PERIOD_M30;
    if(tfPart == "H1") return PERIOD_H1;
    if(tfPart == "H4") return PERIOD_H4;
    if(tfPart == "D1") return PERIOD_D1;
    if(tfPart == "W1") return PERIOD_W1;
    if(tfPart == "MN1") return PERIOD_MN1;
    
    return PERIOD_CURRENT;  // Valor por defecto
}