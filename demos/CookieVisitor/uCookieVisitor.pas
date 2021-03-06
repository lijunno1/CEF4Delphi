// ************************************************************************
// ***************************** CEF4Delphi *******************************
// ************************************************************************
//
// CEF4Delphi is based on DCEF3 which uses CEF3 to embed a chromium-based
// browser in Delphi applications.
//
// The original license of DCEF3 still applies to CEF4Delphi.
//
// For more information about CEF4Delphi visit :
//         https://www.briskbard.com/index.php?lang=en&pageid=cef
//
//        Copyright � 2017 Salvador D�az Fau. All rights reserved.
//
// ************************************************************************
// ************ vvvv Original license and comments below vvvv *************
// ************************************************************************
(*
 *                       Delphi Chromium Embedded 3
 *
 * Usage allowed under the restrictions of the Lesser GNU General Public License
 * or alternatively the restrictions of the Mozilla Public License 1.1
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
 * the specific language governing rights and limitations under the License.
 *
 * Unit owner : Henri Gourvest <hgourvest@gmail.com>
 * Web site   : http://www.progdigy.com
 * Repository : http://code.google.com/p/delphichromiumembedded/
 * Group      : http://groups.google.com/group/delphichromiumembedded
 *
 * Embarcadero Technologies, Inc is not permitted to use or redistribute
 * this source code without explicit permission.
 *
 *)

unit uCookieVisitor;

{$I cef.inc}

interface

uses
  {$IFDEF DELPHI16_UP}
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  {$ELSE}
  Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, StdCtrls, ExtCtrls,
  {$ENDIF}
  uCEFChromium, uCEFWindowParent, uCEFInterfaces, uCEFApplication, uCEFTypes, uCEFConstants,
  uCEFCookieManager, uCEFCookieVisitor;

const
  MINIBROWSER_SHOWCOOKIES   = WM_APP + $101;

  MINIBROWSER_CONTEXTMENU_DELETECOOKIES = MENU_ID_USER_FIRST + 1;
  MINIBROWSER_CONTEXTMENU_GETCOOKIES    = MENU_ID_USER_FIRST + 2;

type
  TCookieVisitorFrm = class(TForm)
    AddressBarPnl: TPanel;
    Edit1: TEdit;
    GoBtn: TButton;
    CEFWindowParent1: TCEFWindowParent;
    Chromium1: TChromium;
    Timer1: TTimer;
    procedure Chromium1AfterCreated(Sender: TObject; const browser: ICefBrowser);
    procedure FormShow(Sender: TObject);
    procedure GoBtnClick(Sender: TObject);
    procedure Chromium1BeforeContextMenu(Sender: TObject;
      const browser: ICefBrowser; const frame: ICefFrame;
      const params: ICefContextMenuParams; const model: ICefMenuModel);
    procedure Chromium1ContextMenuCommand(Sender: TObject;
      const browser: ICefBrowser; const frame: ICefFrame;
      const params: ICefContextMenuParams; commandId: Integer;
      eventFlags: Cardinal; out Result: Boolean);
    procedure Chromium1CookiesDeleted(Sender: TObject;
      numDeleted: Integer);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);

  private
    procedure WMMove(var aMessage : TWMMove); message WM_MOVE;
    procedure WMMoving(var aMessage : TMessage); message WM_MOVING;
    procedure BrowserCreatedMsg(var aMessage : TMessage); message CEF_AFTERCREATED;
    procedure ShowCookiesMsg(var aMessage : TMessage); message MINIBROWSER_SHOWCOOKIES;

  protected
    FText : string;
    FVisitor : ICefCookieVisitor;

  public
    procedure AddCookieInfo(const aCookie : TCookie);

  end;

var
  CookieVisitorFrm: TCookieVisitorFrm;

implementation

{$R *.dfm}

uses
  uSimpleTextViewer;

// This demo has a context menu to test the DeleteCookies function and a CookieVisitor example.

// The cookie visitor gets the global cookie manager to call the VisitAllCookies function.
// The cookie visitor will call CookieVisitorProc for each cookie and it'll save the information using the AddCookieInfo function.
// When the last cookie arrives we show the information in a SimpleTextViewer form.

// This function is called in the IO thread.
function CookieVisitorProc(const name, value, domain, path: ustring;
                                 secure, httponly, hasExpires: Boolean;
                           const creation, lastAccess, expires: TDateTime;
                                 count, total: Integer;
                           out   deleteCookie: Boolean): Boolean;
var
  TempCookie : TCookie;
begin
  deleteCookie := False;

  TempCookie.name        := name;
  TempCookie.value       := value;
  TempCookie.domain      := domain;
  TempCookie.path        := path;
  TempCookie.secure      := secure;
  TempCookie.httponly    := httponly;
  TempCookie.creation    := creation;
  TempCookie.last_access := lastAccess;
  TempCookie.has_expires := hasExpires;
  TempCookie.expires     := expires;

  CookieVisitorFrm.AddCookieInfo(TempCookie);

  if (count = pred(total)) then
    begin
      PostMessage(CookieVisitorFrm.Handle, MINIBROWSER_SHOWCOOKIES, 0, 0);
      Result := False;
    end
   else
    Result := True;
end;

procedure TCookieVisitorFrm.AddCookieInfo(const aCookie : TCookie);
begin
  // This should be protected by a mutex.
  FText := FText + aCookie.name + ' : ' + aCookie.value + #13 + #10;
end;

procedure TCookieVisitorFrm.BrowserCreatedMsg(var aMessage : TMessage);
begin
  CEFWindowParent1.UpdateSize;
  AddressBarPnl.Enabled := True;
  GoBtn.Click;
end;

procedure TCookieVisitorFrm.ShowCookiesMsg(var aMessage : TMessage);
begin
  SimpleTextViewerFrm.Memo1.Lines.Text := FText; // This should be protected by a mutex.
  SimpleTextViewerFrm.ShowModal;
end;

procedure TCookieVisitorFrm.Timer1Timer(Sender: TObject);
begin
  Timer1.Enabled := False;
  if not(Chromium1.CreateBrowser(CEFWindowParent1, '')) and not(Chromium1.Initialized) then
    Timer1.Enabled := True;
end;

procedure TCookieVisitorFrm.GoBtnClick(Sender: TObject);
begin
  Chromium1.LoadURL(Edit1.Text);
end;

procedure TCookieVisitorFrm.Chromium1AfterCreated(Sender: TObject; const browser: ICefBrowser);
begin
  PostMessage(Handle, CEF_AFTERCREATED, 0, 0);
end;

procedure TCookieVisitorFrm.Chromium1BeforeContextMenu(Sender: TObject;
  const browser: ICefBrowser; const frame: ICefFrame;
  const params: ICefContextMenuParams; const model: ICefMenuModel);
begin
  model.AddSeparator;
  model.AddItem(MINIBROWSER_CONTEXTMENU_DELETECOOKIES,  'Delete cookies');
  model.AddSeparator;
  model.AddItem(MINIBROWSER_CONTEXTMENU_GETCOOKIES,     'Visit cookies');
end;

procedure TCookieVisitorFrm.Chromium1ContextMenuCommand(Sender: TObject;
  const browser: ICefBrowser; const frame: ICefFrame;
  const params: ICefContextMenuParams; commandId: Integer;
  eventFlags: Cardinal; out Result: Boolean);
var
  TempManager : ICefCookieManager;
begin
  Result := False;

  case commandId of
    MINIBROWSER_CONTEXTMENU_DELETECOOKIES : Chromium1.DeleteCookies;
    MINIBROWSER_CONTEXTMENU_GETCOOKIES :
      begin
        // This should be protected by a mutex
        FText       := '';
        TempManager := TCefCookieManagerRef.Global(nil);
        TempManager.VisitAllCookies(FVisitor);
      end;
  end;
end;

procedure TCookieVisitorFrm.Chromium1CookiesDeleted(Sender: TObject; numDeleted: Integer);
begin
  showmessage('Deleted cookies : ' + inttostr(numDeleted));
end;

procedure TCookieVisitorFrm.FormCreate(Sender: TObject);
begin
  FVisitor := TCefFastCookieVisitor.Create(CookieVisitorProc);
end;

procedure TCookieVisitorFrm.FormDestroy(Sender: TObject);
begin
  FVisitor := nil;
end;

procedure TCookieVisitorFrm.FormShow(Sender: TObject);
begin
  // GlobalCEFApp.GlobalContextInitialized has to be TRUE before creating any browser
  // If it's not initialized yet, we use a simple timer to create the browser later.
  if not(Chromium1.CreateBrowser(CEFWindowParent1, '')) then Timer1.Enabled := True;
end;

procedure TCookieVisitorFrm.WMMove(var aMessage : TWMMove);
begin
  inherited;

  if (Chromium1 <> nil) then Chromium1.NotifyMoveOrResizeStarted;
end;

procedure TCookieVisitorFrm.WMMoving(var aMessage : TMessage);
begin
  inherited;

  if (Chromium1 <> nil) then Chromium1.NotifyMoveOrResizeStarted;
end;

end.
