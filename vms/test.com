$!  Test.Com - DCL wrapper for perl5 regression test driver
$!
$!  Version 2.0  25-April-2002   Craig Berry  craigberry@mac.com
$!                               (and many other hands in the last 7+ years)
$!  The most significant difference is that we now run the external t/TEST
$!  rather than keeping a separately maintained test driver embedded here.
$!
$!  Version 1.1   4-Dec-1995
$!  Charles Bailey  bailey@newman.upenn.edu
$!
$!  Set up error handler and save things we'll restore later.
$   On Control_Y Then Goto Control_Y_exit
$   On Error Then Goto wrapup
$   olddef = F$Environment("Default")
$   oldmsg = F$Environment("Message")
$   oldpriv = F$SetPrv("NOALL")         ! downgrade privs for safety
$   discard = F$SetPrv("NETMBX,TMPMBX") ! only need these to run tests
$!
$! Process arguments.  P1 is the file extension of the Perl images.  P2,
$! when not empty, indicates that we are testing a version of Perl built for
$! the VMS debugger.  The other arguments are passed directly to t/TEST.
$!
$   exe = ".Exe"
$   If p1.nes."" Then exe = p1
$   If F$Extract(0,1,exe) .nes. "."
$   Then
$     Write Sys$Error ""
$     Write Sys$Error "The first parameter passed to Test.Com must be the file type used for the"
$     Write Sys$Error "images produced when you built Perl (i.e. "".Exe"", unless you edited"
$     Write Sys$Error "Descrip.MMS or used the AXE=1 macro in the MM[SK] command line."
$     Write Sys$Error ""
$     $status = 44
$     goto wrapup
$   EndIf
$!
$!  "debug" perl if second parameter is nonblank
$!
$   dbg = ""
$   ndbg = ""
$   if p2.nes."" then dbg  = "dbg"
$   if p2.nes."" then ndbg = "ndbg"
$!
$!  Make sure we are where we need to be.
$   If F$Search("t.dir").nes.""
$   Then
$       Set Default [.t]
$   Else
$       If F$TrnLNm("Perl_Root").nes.""
$       Then 
$           Set Default Perl_Root:[t]
$       Else
$           Write Sys$Error "Can't find test directory"
$           $status = 44
$           goto wrapup
$       EndIf
$   EndIf
$!
$!  Pick up a copy of perl to use for the tests
$   If F$Search("Perl.").nes."" Then Delete/Log/NoConfirm Perl.;*
$   Copy/Log/NoConfirm [-]'ndbg'Perl'exe' []Perl.
$!
$!  Pick up a copy of vmspipe.com to use for the tests
$   If F$Search("VMSPIPE.COM").nes."" then Delete/Log/Noconfirm VMSPIPE.COM;*
$   Copy/Log/NoConfirm [-]VMSPIPE.COM []
$!
$!  This may be set for the C compiler in descrip.mms, but it confuses the File::Find tests
$   if f$trnlnm("sys") .nes. "" then DeAssign sys
$!
$!  And do it
$   Set Message /NoFacility/NoSeverity/NoIdentification/NoText
$   Show Process/Accounting
$   testdir = "Directory/NoHead/NoTrail/Column=1"
$   PerlShr_filespec = f$parse("Sys$Disk:[-]''dbg'PerlShr''exe'")
$   Define 'dbg'Perlshr 'PerlShr_filespec'
$   If F$Mode() .nes. "INTERACTIVE" Then Define/Nolog PERL_SKIP_TTY_TEST 1
$   MCR Sys$Disk:[]Perl. "-I[-.lib]" TEST. "''p3'" "''p4'" "''p5'" "''p6'"
$   goto wrapup
$!
$ Control_Y_exit:
$   $status = 1552   ! %SYSTEM-W-CONTROLY
$!
$ wrapup:
$   status = $status
$   If f$trnlnm("''dbg'PerlShr") .nes. "" Then DeAssign 'dbg'PerlShr
$   Show Process/Accounting
$   If f$type(olddef) .nes. "" Then Set Default &olddef
$   If f$type(oldmsg) .nes. "" Then Set Message 'oldmsg'
$   If f$type(oldpriv) .nes. "" Then discard = F$SetPrv(oldpriv)
$   Exit status
