program Project2;


{$APPTYPE CONSOLE}

uses
  System.SysUtils, System.JSON, System.Generics.Collections,
  Horse, Horse.Jhonson, System.Classes,
  Data.DB, FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Async,
  FireDAC.DApt, FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteDef,
  Xml.XMLDoc, Xml.XMLIntf, Xml.XMLDom, Xml.adomxmldom, OmniXML;

var
  FDConnection: TFDConnection;

procedure ConfigurarBD;
begin
  FDConnection := TFDConnection.Create(nil);
  FDConnection.LoginPrompt := False;
  FDConnection.DriverName := 'SQLite';
  FDConnection.Params.Values['Database'] := 'delphi.db'; // Asegúrate de que esté en el mismo dir que el .exe
  FDConnection.Connected := True;
end;



function GetChildNodeText(Parent: IXMLNode; const ChildName: string): string;
var
  i: Integer;
begin
  for i := 0 to Parent.ChildNodes.Length - 1 do
  begin
    if SameText(Parent.ChildNodes.Item[i].NodeName, ChildName) then
    begin
      Exit(Trim(Parent.ChildNodes.Item[i].Text));
    end;
  end;

  raise Exception.CreateFmt('Falta el nodo <%s> en uno de los <apunte>.', [ChildName]);
end;


procedure PostOperacion(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  ContentType: string;
  Body: TJSONObject;
  XMLDoc: IXMLDocument;
  RootNode, ApuntesNode, ApunteNode: IXMLNode;
  Q: TFDQuery;
  Fecha: TDateTime;
  Descripcion, Tipo, Cuenta: string;
  Importe, TotalDebe, TotalHaber: Double;
  Apuntes: TJSONArray;
  i,ii: Integer;
  OperacionID: Int64;
  ApuntesTemp: TArray<TJSONObject>;
  ApuntesTempXML: array of TJSONObject;
  j: Integer;
  FechaTexto: string;
  Stream: TStringStream;
  Root: IXMLNode;
  Formato: TFormatSettings;
  FechaNodo: IXMLNode;
  CodigoCuentaNode: IXMLNode;
  CodigoCuentaValue: TJSONValue;
  w: integer;
begin
  ContentType := Req.RawWebRequest.ContentType.ToLower;
  SetLength(ApuntesTemp, 0);
  TotalDebe := 0;
  TotalHaber := 0;

  // 🔹 PARSE JSON
  if ContentType.Contains('application/json') then
  begin
    Body := Req.Body<TJSONObject>;
    Fecha := Body.GetValue<TDateTime>('fecha_operacion');
    Descripcion := Body.GetValue<string>('descripcion');
    Apuntes := Body.GetValue<TJSONArray>('apuntes');

    SetLength(ApuntesTemp, Apuntes.Count);
    for i := 0 to Apuntes.Count - 1 do
    begin
      ApuntesTemp[i] := Apuntes.Items[i] as TJSONObject;
      Importe := ApuntesTemp[i].GetValue<Double>('importe');
      Tipo := ApuntesTemp[i].GetValue<string>('tipo').ToUpper;
      Cuenta := ApuntesTemp[i].GetValue<string>('codigo_cuenta');

      if (Cuenta = '') or (Importe <= 0) or ((Tipo <> 'DEBE') and (Tipo <> 'HABER')) then
      begin
        Res.Status(400).Send('Apunte inválido');
        Exit;
      end;

      if Tipo = 'DEBE' then
        TotalDebe := TotalDebe + Importe
      else
        TotalHaber := TotalHaber + Importe;
    end;
  end

  // 🔹 PARSE XML
  else if ContentType.Contains('application/xml') or ContentType.Contains('text/xml') then

// Parte XML con OmniXML
begin

  Stream := TStringStream.Create(Req.Body, TEncoding.UTF8);
  try
    XMLDoc := CreateXMLDoc;
    Writeln('XML recibido:');
    Writeln(Req.Body);

    XMLDoc.LoadFromStream(Stream);  // ✅ esta es la forma estable con OmniXML puro
    Root := XMLDoc.DocumentElement;
    // Busca el nodo <fecha_operacion>
    FechaNodo := Root.SelectSingleNode('fecha_operacion');
    if not Assigned(FechaNodo) then
    begin
      Res.Status(400).Send('El nodo <fecha_operacion> no se encontró en el XML');
      Exit;
    end;

    FechaTexto := Trim(FechaNodo.Text);
    Descripcion := Root.SelectSingleNode('descripcion').Text;

    Formato := TFormatSettings.Create;
    Formato.DateSeparator := '-';
    Formato.ShortDateFormat := 'dd-mm-yyyy';

    Fecha := StrToDate(FechaTexto, Formato);
    //Fecha := StrToDate(FechaTexto);

    ApuntesNode := Root.SelectSingleNode('apuntes');
    SetLength(ApuntesTemp, ApuntesNode.ChildNodes.Length );
    w := 0;
    for i := 0 to ApuntesNode.ChildNodes.Length  - 1 do
    begin
      ApunteNode := ApuntesNode.ChildNodes.Item[i];
      //
      if (ApunteNode.NodeName <> 'apunte') then
      Continue;
      Writeln('ApunteNode.NodeName = ' + ApunteNode.NodeName);
      Writeln('ApunteNode.HasChildNodes = ' + BoolToStr(ApunteNode.HasChildNodes, True));

      Writeln('Contenido del nodo <apunte> #' + i.ToString + ':');
      Writeln(ApunteNode.XML);

              //
          try
            Cuenta := GetChildNodeText(ApunteNode, 'codigo_cuenta');
            Importe := StrToFloat(GetChildNodeText(ApunteNode, 'importe'));
            Tipo := UpperCase(GetChildNodeText(ApunteNode, 'tipo'));
          except
            on E: Exception do
            begin
              Res.Status(400).Send(E.Message);
              Exit;
            end;
          end;

      // Validación rápida
      if (Cuenta = '') or (Importe <= 0) or ((Tipo <> 'DEBE') and (Tipo <> 'HABER')) then
      begin
        Res.Status(400).Send('Apunte inválido');
        Exit;
      end;

      ApuntesTemp[w] := TJSONObject.Create;
      ApuntesTemp[w].AddPair('codigo_cuenta', Cuenta);
      ApuntesTemp[w].AddPair('importe', TJSONNumber.Create(Importe));
      ApuntesTemp[w].AddPair('tipo', Tipo);
      Inc(w);

      if Tipo = 'DEBE' then
        TotalDebe := TotalDebe + Importe
      else
        TotalHaber := TotalHaber + Importe;
    end;
SetLength(ApuntesTemp, j);
  finally
    Stream.Free;
  end;
end;


  // 🔹 VALIDAR PARTIDA DOBLE
  if Abs(TotalDebe - TotalHaber) > 0.001 then
  begin
    var ErrorJSON := TJSONObject.Create;
    try
      ErrorJSON.AddPair('error',
        Format('La suma del debe (%.2f) no coincide con la suma del haber (%.2f)', [TotalDebe, TotalHaber]));
      Res.Status(400).Send(ErrorJSON.ToJSON);
    finally
      ErrorJSON.Free;
    end;
    Exit;
  end;

  // 🔹 GUARDAR EN BD
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FDConnection;
    Q.SQL.Text := 'INSERT INTO operaciones (fecha_operacion, descripcion) VALUES (:f, :d)';
    Q.ParamByName('f').AsDate := Fecha;
    Q.ParamByName('d').AsString := Descripcion;
    Q.ExecSQL;

    Q.SQL.Text := 'SELECT last_insert_rowid() AS id'; // SQLite
    Q.Open;
    OperacionID := Q.FieldByName('id').AsLargeInt;
    Q.Close;

    for ii := 0 to High(ApuntesTemp) do
    begin
      Q.SQL.Text := 'INSERT INTO apuntes (operacion_id, codigo_cuenta, importe, tipo) ' +
                    'VALUES (:op, :cuenta, :importe, :tipo)';
      Q.ParamByName('op').AsInteger := OperacionID;

  for j := 0 to Length(ApuntesTemp) - 1 do
  begin
    if not Assigned(ApuntesTemp[j]) then
    begin
      Writeln('ApuntesTemp[' + j.ToString + '] está vacío');
      Continue;
    end;

    try
      Writeln('JSON del apunte #' + j.ToString + ': ' + ApuntesTemp[j].ToJSON);
    except
      on E: Exception do
        Writeln('Error al mostrar JSON del apunte #' + j.ToString + ': ' + E.Message);
    end;
  end;

      Q.ParamByName('cuenta').AsString := ApuntesTemp[ii].GetValue<string>('codigo_cuenta');
      Q.ParamByName('importe').AsFloat := ApuntesTemp[ii].GetValue<Double>('importe');
      Q.ParamByName('tipo').AsString := ApuntesTemp[ii].GetValue<string>('tipo');
      Q.ExecSQL;
    end;

    var ResponseJSON := TJSONObject.Create;
    try
      ResponseJSON.AddPair('message', 'Operación registrada correctamente');
      ResponseJSON.AddPair('id_operacion', TJSONNumber.Create(OperacionID));
      Res.Status(201).Send(ResponseJSON.ToJSON);
    finally
      ResponseJSON.Free;
    end;
  finally
    Q.Free;
  end;
end;



procedure GetOperacionById(Req: THorseRequest; Res: THorseResponse; Next: TProc);
var
  Q: TFDQuery;
  OperacionID: Integer;
  OperacionJSON, ApunteJSON: TJSONObject;
  ApuntesArray: TJSONArray;
begin
  OperacionID := Req.Params.Items['id'].ToInteger;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FDConnection;

    // Buscar operación principal
    Q.SQL.Text := 'SELECT id, fecha_operacion, descripcion FROM operaciones WHERE id = :id';
    Q.ParamByName('id').AsInteger := OperacionID;
    Q.Open;

    if Q.IsEmpty then
    begin
      Res.Status(404).Send(Format('No se encontró la operación con ID %d', [OperacionID]));
      Exit;
    end;

    OperacionJSON := TJSONObject.Create;
    try
      OperacionJSON.AddPair('id', TJSONNumber.Create(Q.FieldByName('id').AsInteger));
      OperacionJSON.AddPair('fecha_operacion', Q.FieldByName('fecha_operacion').AsString);
      OperacionJSON.AddPair('descripcion', Q.FieldByName('descripcion').AsString);

      Q.Close;

      // Buscar apuntes asociados
      Q.SQL.Text := 'SELECT codigo_cuenta, importe, tipo FROM apuntes WHERE operacion_id = :id';
      Q.ParamByName('id').AsInteger := OperacionID;
      Q.Open;

      ApuntesArray := TJSONArray.Create;
      while not Q.Eof do
      begin
        ApunteJSON := TJSONObject.Create;
        ApunteJSON.AddPair('codigo_cuenta', Q.FieldByName('codigo_cuenta').AsString);
        ApunteJSON.AddPair('importe', TJSONNumber.Create(Q.FieldByName('importe').AsFloat));
        ApunteJSON.AddPair('tipo', Q.FieldByName('tipo').AsString);
        ApuntesArray.AddElement(ApunteJSON);
        Q.Next;
      end;

      OperacionJSON.AddPair('apuntes', ApuntesArray);

      Res.Status(200).Send(OperacionJSON.ToJSON);
    finally
      OperacionJSON.Free;
    end;
  finally
    Q.Free;
  end;
end;


begin
  ReportMemoryLeaksOnShutdown := True;

  ConfigurarBD;

  THorse.Use(Jhonson);
  THorse.Post('/api/operaciones', PostOperacion);
  THorse.Get('/api/operaciones/:id', GetOperacionById);


  Writeln('Servidor corriendo en http://localhost:9000');
  try
    THorse.Listen(9000);
  finally
    FDConnection.Connected := False;
    FDConnection.Free;
  end;
end.

