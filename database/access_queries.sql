--- ~sq_ffrmContactLevels ---
SELECT DISTINCTROW  FROM [tblContactLevels] 
--- ~sq_ffrmPrefix ---
SELECT DISTINCTROW  FROM [tblPrefix] 
--- ~sq_ffrmSecurity ---
SELECT DISTINCTROW  FROM [tblSecurity] 
--- ConvertAdvertisers ---
SELECT ExcelAdvertisers.Advertiser,ExcelAdvertisers.AcctExecID,ExcelAdvertisers.AdvertiserOrLead FROM [ExcelAdvertisers] 
--- ConvertLeads ---
SELECT ExcelLeads.Advertiser,ExcelLeads.AcctExecID,ExcelLeads.AdvertiserOrLead FROM [ExcelLeads] 
--- dltComment ---
SELECT tblcomments.* FROM [tblComments] WHERE (((tblComments.CommentID)=88853)) 
--- Find ---
--- duplicates ---
--- for ---
--- tblAdvertisers1 ---
--- qry_CONCAT_Merge_5and6 ---
SELECT DISTINCT  FROM [],[] 
--- qry_CONCAT_MergeAllSuiteChanges ---
SELECT DISTINCT  FROM [],[] 
--- qry_CONCAT_NotInMergeButNeedResearch ---
SELECT 'tblAdvertisers','',tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.Street,tblAdvertisers.Suite,"REVIEW : Already had suite in address." FROM [tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvertisers.AdvertiserID) Not In (SELECT qry_CONCAT_Merge_5and6.AdvertiserID FROM qry_CONCAT_Merge_5and6)) AND ((tblAdvertisers.Suite) Is Not Null)) 
--- qry_CONCAT_NotInSuitePop ---
SELECT "tblAdvertisers","",tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.Street,tblAdvertisers.Suite,"No Change needed." FROM [tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvertisers.AdvertiserID) Not In (select [qry_CONCAT_MergeAllSuiteChanges].[AdvertiserID] from [qry_CONCAT_MergeAllSuiteChanges]))) 
--- qry_Concat_StreetAndSuite_2 ---
SELECT 'tblAdvContacts01',tblAdvContacts01.ContactID,tblAdvContacts01.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvContacts01.Street,tblAdvContacts01.Suite,[tblAdvContacts01].[Street] & ', Suite ' & [tblAdvContacts01].[Suite] FROM [tblAcctExecs],[tblAdvContacts01],[tblAdvertisers] WHERE (((tblAdvContacts01.Street) Not Like '*' & tblAdvContacts01.Suite & '*') And ((tblAdvContacts01.Suite) Is Not Null)) 
--- qry_Concat_StreetAndSuite_3 ---
SELECT 'tblAdvContacts02',tblAdvContacts02.ContactID,tblAdvContacts02.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvContacts02.Street,tblAdvContacts02.Suite,[tblAdvContacts02].[Street] & ', Suite ' & [tblAdvContacts02].[Suite] FROM [tblAcctExecs],[tblAdvContacts02],[tblAdvertisers] WHERE (((tblAdvContacts02.Street) Not Like '*' & tblAdvContacts02.Suite & '*') And ((tblAdvContacts02.Suite) Is Not Null)) 
--- qry_Concat_StreetAndSuite_4 ---
SELECT 'tblAdvContacts1',tblAdvContacts1.ContactID,tblAdvContacts1.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvContacts1.Street,tblAdvContacts1.Suite,[tblAdvContacts1].[Street] & ', Suite ' & [tblAdvContacts1].[Suite] FROM [tblAcctExecs],[tblAdvContacts1],[tblAdvertisers] WHERE (((tblAdvContacts1.Street) Not Like '*' & tblAdvContacts1.Suite & '*') And ((tblAdvContacts1.Suite) Is Not Null)) 
--- qry_Concat_StreetAndSuite_5 ---
SELECT 'tblAdvertisers','',tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.Street,tblAdvertisers.Suite,[tblAdvertisers].[Street] & ', Suite ' & [tblAdvertisers].[Suite] FROM [tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvertisers.Street) Not Like '*Suite*' And (tblAdvertisers.Street) Not Like '*ste*') AND ((tblAdvertisers.Suite) Is Not Null And (tblAdvertisers.Suite) Not Like '*Suite*')) 
--- qryAcctExecs ---
SELECT tblAcctExecs.AcctExecID,tblAcctExecs.AcctExec,tblAcctExecs.Terminated FROM [tblAcctExecs] WHERE (((tblAcctExecs.Terminated)=0)) ORDER BY tblAcctExecs.AcctExec
--- qryAdvertiserList ---
SELECT tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,([qryAdvPrimaryContacts]![FName] & " " & [qryAdvPrimaryContacts]![LName]),tblAdvertisers.Street,tblAdvertisers.City,tblAdvertisers.St,tblAdvertisers.Zip,tblAdvertisers.Phone,tblAdvertisers.PhExt,tblAdvertisers.Email,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.ContractExpires,tblAdvertisers.InitialContactDate,qryCommentDateLatest.[Last Contact],tblAdvertisers.Temp,tblAdvertisers.Active,tblBusinessType.BusinessType FROM [tblAcctExecs],[tblAdvertisers],[qryCommentDateLatest],[tblBusinessType],[qryAdvPrimaryContacts] WHERE tblAdvertisers.Advertiser Like "***" ORDER BY tblAdvertisers.Advertiser
--- qryAdvertiserListExport ---
SELECT qryAdvertiserList.AdvertiserID,qryAdvertiserList.Advertiser,qryAdvertiserList.Street,qryAdvertiserList.City,qryAdvertiserList.St,qryAdvertiserList.Zip,qryAdvertiserList.Phone,qryAdvertiserList.PhExt,qryAdvertiserList.Email,qryAdvertiserList.[Account Manager],qryAdvertiserList.Category,qryAdvertiserList.[Contract Expires],qryAdvertiserList.[Initial Contact],qryAdvertiserList.[Last Contact],qryAdvertiserList.Temp,qryAdvertiserList.Active,qryAdvertiserList.BusinessType,[tblAdvContacts]![Prefix] & " " & [tblAdvContacts]![FName] & " " & [tblAdvContacts]![LName] & " " & [tblAdvContacts]![Suffix],tblAdvContacts.Primary,tblAdvContacts.FName,tblAdvContacts.LName,tblAdvContacts.Prefix,tblAdvContacts.Suffix,tblAdvContacts.CoTitle,tblAdvContacts.EMail,tblAdvContacts.Ph,tblAdvContacts.PhExt,tblAdvContacts.Street,tblAdvContacts.Suite,tblAdvContacts.City,tblAdvContacts.ST,tblAdvContacts.ZIP,tblAdvContacts.Organization,tblAdvContacts.ContactLevel,tblAdvContacts.PhCell,tblAdvContacts.PhFax,tblAdvContacts.Primary,tblAdvContacts.PrimarySeq FROM [tblAdvContacts],[qryAdvertiserList] ORDER BY qryAdvertiserList.Advertiser
--- qryAdvertiserListExportPrimary ---
SELECT qryAdvertiserList.AdvertiserID,qryAdvertiserList.Advertiser,qryAdvertiserList.Street,qryAdvertiserList.City,qryAdvertiserList.St,qryAdvertiserList.Zip,qryAdvertiserList.Phone,qryAdvertiserList.PhExt,qryAdvertiserList.Email,qryAdvertiserList.[Account Manager],qryAdvertiserList.Category,qryAdvertiserList.[Contract Expires],qryAdvertiserList.[Initial Contact],qryAdvertiserList.[Last Contact],qryAdvertiserList.Temp,qryAdvertiserList.Active,qryAdvertiserList.BusinessType,[tblAdvContacts]![Prefix] & " " & [tblAdvContacts]![FName] & " " & [tblAdvContacts]![LName] & " " & [tblAdvContacts]![Suffix],tblAdvContacts.Primary,tblAdvContacts.FName,tblAdvContacts.LName,tblAdvContacts.Prefix,tblAdvContacts.Suffix,tblAdvContacts.CoTitle,tblAdvContacts.EMail,tblAdvContacts.Ph,tblAdvContacts.PhExt,tblAdvContacts.Street,tblAdvContacts.Suite,tblAdvContacts.City,tblAdvContacts.ST,tblAdvContacts.ZIP,tblAdvContacts.Organization,tblAdvContacts.ContactLevel,tblAdvContacts.PhCell,tblAdvContacts.PhFax,tblAdvContacts.Primary,tblAdvContacts.PrimarySeq FROM [tblAdvContacts],[qryAdvertiserList] WHERE (((tblAdvContacts.Primary)="Y")) ORDER BY qryAdvertiserList.Advertiser
--- qryAdvPrimaryContacts ---
SELECT tblAdvContacts.AdvertiserID,tblAdvContacts.FName,tblAdvContacts.LName,tblAdvContacts.Primary FROM [tblAdvContacts] WHERE (((tblAdvContacts.Primary)="Y")) 
--- qryAlternateContact ---
SELECT 2 FROM [tblAdvContacts] WHERE (((tblAdvContacts.ContactLevel)="Alternate")) 
--- qryChronologicalComments ---
SELECT tblAdvertisers!Advertiser,tblAcctExecs.AcctExec,tblComments.CommentDate,tblComments.CommentTime,tblComments.Comment FROM [tblComments],[tblAdvertisers],[tblAcctExecs] ORDER BY tblComments.CommentDate
--- qryCmbAcctExecID ---
SELECT tblAcctExecs.AcctExecID,tblAcctExecs.AcctExec FROM [tblAcctExecs] WHERE (((tblAcctExecs.Terminated)=0)) ORDER BY tblAcctExecs.AcctExec
--- qryCmbAdvertiserOrLead ---
SELECT tblProductCategories.AdvertiserOrLead,tblProductCategories.AorLDescr FROM [tblProductCategories] WHERE (((tblProductCategories.AdvertiserOrLead)<>"All")) ORDER BY tblProductCategories.SortSeq
--- qryCmbAE ---
SELECT tblAcctExecs.AcctExecID,tblAcctExecs.AcctExec FROM [tblAcctExecs] WHERE (((tblAcctExecs.Terminated)=0)) ORDER BY tblAcctExecs.AcctExec
--- qryCmbAllAorP ---
SELECT tblProductCategories.AdvertiserOrLead,tblProductCategories.AorLDescr FROM [tblProductCategories] ORDER BY tblProductCategories.SortSeq
--- qryCmbBusinessType ---
SELECT tblBusinessType.BusinessTypeID,tblBusinessType.BusinessType FROM [tblBusinessType] ORDER BY tblBusinessType.BusinessType
--- qryCmbContactLevel ---
SELECT tblContactLevels.ContactLevel,tblContactLevels.SortSeq FROM [tblContactLevels] ORDER BY tblContactLevels.SortSeq
--- qryCommentDateLatest ---
SELECT tblComments.AdvertiserID,Max(tblComments.CommentDate) FROM [tblComments] ORDER BY tblComments.AdvertiserID
--- qryContactList ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Contact,tblAdvertisers.Phone,tblAcctExecs.AcctExec,tblAdvertisers.InitialContactDate,tblAdvertisers.LastContactDate,tblAdvertisers.Dead,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.AdvertiserID FROM [tblAcctExecs],[tblAdvertisers] WHERE tblAdvertisers.AdvertiserOrLead="L" ORDER BY tblAdvertisers.Advertiser
--- qryContactLvlClient ---
SELECT "Client",1 FROM [tblAdvContacts] 
--- qryContractType ---
SELECT tblContractType.ContractType FROM [tblContractType] ORDER BY tblContractType.SortID
--- qryCreateTblAdvContactsAlt ---
SELECT tblAdvertisers.AdvertiserID,IIf([FirstBlank]=0,"",Right([tblAdvertisers]![AlternateContact],Len([tblAdvertisers]![AlternateContact])-[FirstBlank])),IIf([FirstBlank]=0,[tblAdvertisers]![AlternateContact],Left([tblAdvertisers]![AlternateContact],[FirstBlank]-1)),Null,Null,Null,tblAdvertisers.Email,tblAdvertisers.Phone,tblAdvertisers.PhExt,tblAdvertisers.Street,tblAdvertisers.Suite,tblAdvertisers.City,tblAdvertisers.ST,tblAdvertisers.ZIP,tblAdvertisers.Advertiser,"Alternate",2,InStr(1,[tblAdvertisers]![AlternateContact]," ",1),Null,Null FROM [tblAdvertisers] WHERE (((InStr(1,[tblAdvertisers]![AlternateContact]," ",1)) Is Not Null)) 
--- qryCreateTblAdvContactsxxx ---
SELECT tblAdvertisers.AdvertiserID,IIf([FirstBlank]=0,"",Right([tblAdvertisers]![Contact],Len([tblAdvertisers]![Contact])-[FirstBlank])),IIf([FirstBlank]=0,[tblAdvertisers]![Contact],Left([tblAdvertisers]![Contact],[FirstBlank]-1)),Null,Null,[tblAdvertisers]![Title],tblAdvertisers.Email,[tblAdvertisers]![Phone],tblAdvertisers.PhExt,tblAdvertisers.Street,tblAdvertisers.Suite,tblAdvertisers.City,tblAdvertisers.ST,tblAdvertisers.ZIP,[tblAdvertisers]![Advertiser],"Primary",Null,Null,InStr(1,[tblAdvertisers]![Contact]," ",1) FROM [tblAdvertisers] WHERE (((InStr(1,[tblAdvertisers]![Contact]," ",1)) Is Not Null)) 
--- qryDeleteAdvertiser ---
SELECT tblAdvertisers.*,tblAdvertisers.AdvertiserID FROM [tblAdvertisers] WHERE (((tblAdvertisers.AdvertiserID)=11107)) 
--- QryGtoP ---
SELECT "P" FROM [tblAdvertisers] WHERE (((tblAdvertisers.AdvertiserOrLead)="G")) 
--- qryNullAdvAltContacts ---
SELECT tblAdvertisers.AlternateContact,tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser FROM [tblAdvertisers] WHERE (((tblAdvertisers.AlternateContact) Is Null)) ORDER BY tblAdvertisers.Advertiser
--- qryNullAdvContacts ---
SELECT tblAdvertisers.Contact,tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser FROM [tblAdvertisers] WHERE (((tblAdvertisers.Contact) Is Null)) ORDER BY tblAdvertisers.Advertiser
--- qryPrefix ---
SELECT tblPrefix.Prefix FROM [tblPrefix] ORDER BY tblPrefix.SortSeq
--- qryProspectList ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Contact,tblAdvertisers.Phone,tblAcctExecs.AcctExec,tblAdvertisers.InitialContactDate,tblAdvertisers.LastContactDate,tblAdvertisers.Dead,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.AdvertiserID FROM [tblAcctExecs],[tblAdvertisers] WHERE tblAdvertisers.AdvertiserOrLead="P" ORDER BY tblAdvertisers.Advertiser
--- qryRptAdvertisers ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Contact,tblAcctExecs.AcctExec,tblAdvertisers.LastContactDate,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.InitialContactDate,tblAdvertisers.ContractExpires,tblAdvertisers.ContractType,qryCommentDateLatest.[Last Contact],tblAdvertisers.Temp FROM [tblAcctExecs],[tblAdvertisers],[qryCommentDateLatest] ORDER BY tblAdvertisers.Advertiser
--- qrySfrmAdvContacts ---
SELECT tblAdvContacts.PrimarySeq,tblAdvContacts.ContactID,tblAdvContacts.AdvertiserID,tblAdvContacts.ContactLevelSeq,tblAdvContacts.LName,tblAdvContacts.FName,tblAdvContacts.Prefix,tblAdvContacts.Suffix,tblAdvContacts.CoTitle,tblAdvContacts.EMail,tblAdvContacts.Ph,tblAdvContacts.PhExt,tblAdvContacts.Street,tblAdvContacts.Suite,tblAdvContacts.City,tblAdvContacts.ST,tblAdvContacts.ZIP,tblAdvContacts.Organization,tblAdvContacts.ContactLevel,tblAdvContacts.PhCell,tblAdvContacts.PhFax,tblAdvContacts.Primary,tblAdvContacts.Website FROM [tblAdvContacts] ORDER BY tblAdvContacts.PrimarySeq
--- qrySfrmComments ---
SELECT tblComments.CommentID,tblComments.AdvertiserID,tblComments.CommentDate,tblComments.CommentTime,tblComments.Comment,tblAcctExecs.AcctExec FROM [tblComments],[tblAcctExecs] WHERE (((tblComments.AdvertiserID)=Forms!frmAdvertisers!AdvertiserID)) ORDER BY tblComments.CommentDate
--- qryStPostalCd ---
SELECT tblStPostalCd.ST FROM [tblStPostalCd] ORDER BY tblStPostalCd.ST
--- qrySuffix ---
SELECT tblSuffix.Suffix FROM [tblSuffix] ORDER BY tblSuffix.SortSeq
--- qryTestAdvSelection ---
SELECT tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,([qryAdvPrimaryContacts]![FName] & " " & [qryAdvPrimaryContacts]![LName]),tblAdvertisers.Street,tblAdvertisers.City,tblAdvertisers.St,tblAdvertisers.Zip,tblAdvertisers.Phone,tblAdvertisers.PhExt,tblAdvertisers.Email,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.ContractDate,tblAdvertisers.InitialContactDate,qryCommentDateLatest.[Last Contact],tblAdvertisers.Temp,tblAdvertisers.Active,tblBusinessType.BusinessType FROM [tblAcctExecs],[tblAdvertisers],[qryCommentDateLatest],[tblBusinessType],[qryAdvPrimaryContacts] ORDER BY tblAdvertisers.Advertiser
--- Query1 ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Contact,tblAdvertisers.Phone,tblAcctExecs.AcctExec,tblAdvertisers.LastContactDate,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.AdvertiserID FROM [tblAcctExecs],[tblAdvertisers] WHERE tblAdvertisers.AdvertiserOrLead="A" And tblAdvertisers.Advertiser Like "bellai*" ORDER BY tblAdvertisers.Advertiser
--- Query2 ---
SELECT tblAdvertisers.AcctExecID,tblAdvertisers.AdvertiserOrLead FROM [tblAdvertisers] WHERE (((tblAdvertisers.AcctExecID)=Forms!frmAdvertisers!cmbAcctExecID) And ((tblAdvertisers.AdvertiserOrLead)="L")) 
--- Query3a ---
SELECT tblAdvertisers.AdvertiserID,tblAdvertisers.AcctExecID,tblAdvertisers.AdvertiserOrLead FROM [tblAdvertisers] WHERE (((tblAdvertisers.AdvertiserOrLead)="P")) ORDER BY tblAdvertisers.AcctExecID
--- Query4 ---
SELECT tblPPAMaxQty.AdvertiserOrLead,tblPPAMaxQty.MaxQty FROM [tblPPAMaxQty] WHERE (((tblPPAMaxQty.AdvertiserOrLead)=[Forms]![frmAdvertisers]![cmbAdvertiserOrLead])) 
--- updFillBlankInitialDate ---
SELECT #6/1/2006# FROM [tblAdvertisers] WHERE (((tblAdvertisers.InitialContactDate) Is Null)) 
--- updLeadsToProspects ---
SELECT "P" FROM [tblAdvertisers] WHERE (((tblAdvertisers.AdvertiserOrLead)="L")) 
--- updOpenProspectsToCold ---
SELECT "Cold" FROM [tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvertisers.AcctExecID)=11)) 
--- ~sq_ffrmPPAMaxQty ---
SELECT DISTINCTROW  FROM [tblPPAMaxQty] 
--- ~sq_ffrmProductCategories ---
SELECT DISTINCTROW  FROM [tblProductCategories] 
--- ~sq_ffrmSuffix ---
SELECT DISTINCTROW  FROM [tblSuffix] 
--- Find ---
--- duplicates ---
--- for ---
--- tblAdvertisers ---
SELECT  FROM  
--- qry_CONCAT_FullPop ---
SELECT DISTINCT  FROM [],[] 
--- qry_Concat_StreetAndSuite ---
SELECT "tblAdvContacts",tblAdvContacts.ContactID,tblAdvContacts.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvContacts.Street,tblAdvContacts.Suite,[tblAdvContacts].[Street] & ', Suite ' & [tblAdvContacts].[Suite] FROM [tblAdvContacts],[tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvContacts.Street) Not Like '*' & [tblAdvContacts].[Suite] & '*') AND ((tblAdvContacts.Suite) Is Not Null)) 
--- qry_Concat_StreetAndSuite_6 ---
SELECT 'tblAdvertisers','',tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.Street,tblAdvertisers.Suite,[tblAdvertisers].[Street] & ',  ' & [tblAdvertisers].[Suite] FROM [tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvertisers.Street) Not Like '*Suite*' And (tblAdvertisers.Street) Not Like '*ste*') AND ((tblAdvertisers.Suite) Like '*Suite*')) 
--- qryAdvertisers ---
SELECT tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,tblAdvertisers.Street,tblAdvertisers.Suite,tblAdvertisers.City,tblAdvertisers.ST,tblAdvertisers.ZIP,tblAdvertisers.Contact,tblAdvertisers.Title,tblAdvertisers.Phone,tblAdvertisers.PhExt,tblAdvertisers.Fax,tblAdvertisers.Email,tblAdvertisers.AlternateContact,tblAdvertisers.AcctExecID,tblAdvertisers.EntryDate,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.LastContactDate,tblAdvertisers.Comments,tblAdvertisers.InitialContactDate,tblAdvertisers.Dead,tblAdvertisers.Temp,tblAdvertisers.Active,tblAdvertisers.ContractExpires,tblAdvertisers.BusinessType,tblAdvertisers.ContractType,tblAdvertisers.Website FROM [tblAdvertisers] ORDER BY tblAdvertisers.Advertiser
--- qryChronologicalCommentsTemplate ---
SELECT tblAdvertisers!Advertiser & " " & tblAdvertisers!Street,tblAcctExecs.AcctExec,tblComments.CommentDate,tblComments.CommentTime,tblComments.Comment FROM [tblComments],[tblAdvertisers],[tblAcctExecs] ORDER BY tblAdvertisers!Advertiser & " " & tblAdvertisers!Street
--- qryCmdPrimaryContact ---
SELECT tblPrimaryContact.Primary,tblPrimaryContact.PrimarySeq FROM [tblPrimaryContact] ORDER BY tblPrimaryContact.PrimarySeq DESCENDING
--- qryCreateTblAdvContacts ---
SELECT tblAdvertisers.AdvertiserID,IIf([FirstBlank]=0,"",Right([tblAdvertisers]![Contact],Len([tblAdvertisers]![Contact])-[FirstBlank])),IIf([FirstBlank]=0,[tblAdvertisers]![Contact],Left([tblAdvertisers]![Contact],[FirstBlank]-1)),Null,Null,[tblAdvertisers]![Title],tblAdvertisers.Email,[tblAdvertisers]![Phone],tblAdvertisers.PhExt,tblAdvertisers.Street,tblAdvertisers.Suite,tblAdvertisers.City,tblAdvertisers.ST,tblAdvertisers.ZIP,[tblAdvertisers]![Advertiser],"Primary",1,Null,Null,InStr(1,[tblAdvertisers]![Contact]," ",1) FROM [tblAdvertisers] WHERE (((InStr(1,[tblAdvertisers]![Contact]," ",1)) Is Not Null)) 
--- qryListTemplate ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Contact,tblAdvertisers.Phone,tblAdvertisers.AdvertiserOrLead,tblAcctExecs.AcctExec,tblAdvertisers.InitialContactDate,qryCommentDateLatest.[Last Contact],tblAdvertisers.Temp,tblAdvertisers.Active,tblAdvertisers.AdvertiserID FROM [tblAcctExecs],[tblAdvertisers],[qryCommentDateLatest] 
--- qryPrimaryContact ---
SELECT "X",1 FROM [tblAdvContacts] WHERE (((tblAdvContacts.ContactLevel)="Primary")) 
--- qrySelectAdvertiser ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Street,tblAdvertisers.City,tblAdvertisers.ZIP FROM [tblAdvertisers] ORDER BY tblAdvertisers.Advertiser
--- QryTest ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Contact,tblAdvertisers.Phone,tblAcctExecs.AcctExec,tblAdvertisers.LastContactDate,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.AdvertiserID FROM [tblAcctExecs],[tblAdvertisers] WHERE (((tblAdvertisers.Advertiser) Like Forms!frmAdvertiserAndContactLists!txtSelectAdvertiser+"*") And ((tblAdvertisers.AdvertiserOrLead)="A")) ORDER BY tblAdvertisers.Advertiser
--- Query3 ---
SELECT Count(tblAdvertisers.AdvertiserID) FROM [tblAdvertisers] 
--- Query5 ---
SELECT tblAdvContacts.ContactID,tblAdvContacts.AdvertiserID,tblAdvContacts.FName,tblAdvContacts.LName,tblAdvContacts.Primary,tblAdvContacts.PrimarySeq,tblAdvContacts.ContactLevel,tblAdvContacts.ContactLevelSeq FROM [tblAdvContacts] WHERE (((tblAdvContacts.AdvertiserID)=8318)) 
--- QUERY: ~sq_ffrmContactLevels ---
SELECT DISTINCTROW  FROM [tblContactLevels] 


--- QUERY: ~sq_ffrmPrefix ---
SELECT DISTINCTROW  FROM [tblPrefix] 


--- QUERY: ~sq_ffrmSecurity ---
SELECT DISTINCTROW  FROM [tblSecurity] 


--- QUERY: ConvertAdvertisers ---
SELECT ExcelAdvertisers.Advertiser,ExcelAdvertisers.AcctExecID,ExcelAdvertisers.AdvertiserOrLead FROM [ExcelAdvertisers] 


--- QUERY: ConvertLeads ---
SELECT ExcelLeads.Advertiser,ExcelLeads.AcctExecID,ExcelLeads.AdvertiserOrLead FROM [ExcelLeads] 


--- QUERY: dltComment ---
SELECT tblcomments.* FROM [tblComments] WHERE (((tblComments.CommentID)=88853)) 


--- QUERY: Find duplicates for tblAdvertisers1 ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Street,tblAdvertisers.Contact,tblAcctExecs.AcctExec FROM [tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvertisers.Advertiser) In (SELECT [Advertiser] FROM [tblAdvertisers] As Tmp GROUP BY [Advertiser],[Street] HAVING Count(*)>1  And [Street] = [tblAdvertisers].[Street]))) ORDER BY tblAdvertisers.Advertiser


--- QUERY: qry_CONCAT_Merge_5and6 ---
SELECT DISTINCT  FROM [],[] 


--- QUERY: qry_CONCAT_MergeAllSuiteChanges ---
SELECT DISTINCT  FROM [],[] 


--- QUERY: qry_CONCAT_NotInMergeButNeedResearch ---
SELECT 'tblAdvertisers','',tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.Street,tblAdvertisers.Suite,"REVIEW : Already had suite in address." FROM [tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvertisers.AdvertiserID) Not In (SELECT qry_CONCAT_Merge_5and6.AdvertiserID FROM qry_CONCAT_Merge_5and6)) AND ((tblAdvertisers.Suite) Is Not Null)) 


--- QUERY: qry_CONCAT_NotInSuitePop ---
SELECT "tblAdvertisers","",tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.Street,tblAdvertisers.Suite,"No Change needed." FROM [tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvertisers.AdvertiserID) Not In (select [qry_CONCAT_MergeAllSuiteChanges].[AdvertiserID] from [qry_CONCAT_MergeAllSuiteChanges]))) 


--- QUERY: qry_Concat_StreetAndSuite_2 ---
SELECT 'tblAdvContacts01',tblAdvContacts01.ContactID,tblAdvContacts01.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvContacts01.Street,tblAdvContacts01.Suite,[tblAdvContacts01].[Street] & ', Suite ' & [tblAdvContacts01].[Suite] FROM [tblAcctExecs],[tblAdvContacts01],[tblAdvertisers] WHERE (((tblAdvContacts01.Street) Not Like '*' & tblAdvContacts01.Suite & '*') And ((tblAdvContacts01.Suite) Is Not Null)) 


--- QUERY: qry_Concat_StreetAndSuite_3 ---
SELECT 'tblAdvContacts02',tblAdvContacts02.ContactID,tblAdvContacts02.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvContacts02.Street,tblAdvContacts02.Suite,[tblAdvContacts02].[Street] & ', Suite ' & [tblAdvContacts02].[Suite] FROM [tblAcctExecs],[tblAdvContacts02],[tblAdvertisers] WHERE (((tblAdvContacts02.Street) Not Like '*' & tblAdvContacts02.Suite & '*') And ((tblAdvContacts02.Suite) Is Not Null)) 


--- QUERY: qry_Concat_StreetAndSuite_4 ---
SELECT 'tblAdvContacts1',tblAdvContacts1.ContactID,tblAdvContacts1.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvContacts1.Street,tblAdvContacts1.Suite,[tblAdvContacts1].[Street] & ', Suite ' & [tblAdvContacts1].[Suite] FROM [tblAcctExecs],[tblAdvContacts1],[tblAdvertisers] WHERE (((tblAdvContacts1.Street) Not Like '*' & tblAdvContacts1.Suite & '*') And ((tblAdvContacts1.Suite) Is Not Null)) 


--- QUERY: qry_Concat_StreetAndSuite_5 ---
SELECT 'tblAdvertisers','',tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.Street,tblAdvertisers.Suite,[tblAdvertisers].[Street] & ', Suite ' & [tblAdvertisers].[Suite] FROM [tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvertisers.Street) Not Like '*Suite*' And (tblAdvertisers.Street) Not Like '*ste*') AND ((tblAdvertisers.Suite) Is Not Null And (tblAdvertisers.Suite) Not Like '*Suite*')) 


--- QUERY: qryAcctExecs ---
SELECT tblAcctExecs.AcctExecID,tblAcctExecs.AcctExec,tblAcctExecs.Terminated FROM [tblAcctExecs] WHERE (((tblAcctExecs.Terminated)=0)) ORDER BY tblAcctExecs.AcctExec


--- QUERY: qryAdvertiserList ---
SELECT tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,([qryAdvPrimaryContacts]![FName] & " " & [qryAdvPrimaryContacts]![LName]),tblAdvertisers.Street,tblAdvertisers.City,tblAdvertisers.St,tblAdvertisers.Zip,tblAdvertisers.Phone,tblAdvertisers.PhExt,tblAdvertisers.Email,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.ContractExpires,tblAdvertisers.InitialContactDate,qryCommentDateLatest.[Last Contact],tblAdvertisers.Temp,tblAdvertisers.Active,tblBusinessType.BusinessType FROM [tblAcctExecs],[tblAdvertisers],[qryCommentDateLatest],[tblBusinessType],[qryAdvPrimaryContacts] WHERE tblAdvertisers.Advertiser Like "***" ORDER BY tblAdvertisers.Advertiser


--- QUERY: qryAdvertiserListExport ---
SELECT qryAdvertiserList.AdvertiserID,qryAdvertiserList.Advertiser,qryAdvertiserList.Street,qryAdvertiserList.City,qryAdvertiserList.St,qryAdvertiserList.Zip,qryAdvertiserList.Phone,qryAdvertiserList.PhExt,qryAdvertiserList.Email,qryAdvertiserList.[Account Manager],qryAdvertiserList.Category,qryAdvertiserList.[Contract Expires],qryAdvertiserList.[Initial Contact],qryAdvertiserList.[Last Contact],qryAdvertiserList.Temp,qryAdvertiserList.Active,qryAdvertiserList.BusinessType,[tblAdvContacts]![Prefix] & " " & [tblAdvContacts]![FName] & " " & [tblAdvContacts]![LName] & " " & [tblAdvContacts]![Suffix],tblAdvContacts.Primary,tblAdvContacts.FName,tblAdvContacts.LName,tblAdvContacts.Prefix,tblAdvContacts.Suffix,tblAdvContacts.CoTitle,tblAdvContacts.EMail,tblAdvContacts.Ph,tblAdvContacts.PhExt,tblAdvContacts.Street,tblAdvContacts.Suite,tblAdvContacts.City,tblAdvContacts.ST,tblAdvContacts.ZIP,tblAdvContacts.Organization,tblAdvContacts.ContactLevel,tblAdvContacts.PhCell,tblAdvContacts.PhFax,tblAdvContacts.Primary,tblAdvContacts.PrimarySeq FROM [tblAdvContacts],[qryAdvertiserList] ORDER BY qryAdvertiserList.Advertiser


--- QUERY: qryAdvertiserListExportPrimary ---
SELECT qryAdvertiserList.AdvertiserID,qryAdvertiserList.Advertiser,qryAdvertiserList.Street,qryAdvertiserList.City,qryAdvertiserList.St,qryAdvertiserList.Zip,qryAdvertiserList.Phone,qryAdvertiserList.PhExt,qryAdvertiserList.Email,qryAdvertiserList.[Account Manager],qryAdvertiserList.Category,qryAdvertiserList.[Contract Expires],qryAdvertiserList.[Initial Contact],qryAdvertiserList.[Last Contact],qryAdvertiserList.Temp,qryAdvertiserList.Active,qryAdvertiserList.BusinessType,[tblAdvContacts]![Prefix] & " " & [tblAdvContacts]![FName] & " " & [tblAdvContacts]![LName] & " " & [tblAdvContacts]![Suffix],tblAdvContacts.Primary,tblAdvContacts.FName,tblAdvContacts.LName,tblAdvContacts.Prefix,tblAdvContacts.Suffix,tblAdvContacts.CoTitle,tblAdvContacts.EMail,tblAdvContacts.Ph,tblAdvContacts.PhExt,tblAdvContacts.Street,tblAdvContacts.Suite,tblAdvContacts.City,tblAdvContacts.ST,tblAdvContacts.ZIP,tblAdvContacts.Organization,tblAdvContacts.ContactLevel,tblAdvContacts.PhCell,tblAdvContacts.PhFax,tblAdvContacts.Primary,tblAdvContacts.PrimarySeq FROM [tblAdvContacts],[qryAdvertiserList] WHERE (((tblAdvContacts.Primary)="Y")) ORDER BY qryAdvertiserList.Advertiser


--- QUERY: qryAdvPrimaryContacts ---
SELECT tblAdvContacts.AdvertiserID,tblAdvContacts.FName,tblAdvContacts.LName,tblAdvContacts.Primary FROM [tblAdvContacts] WHERE (((tblAdvContacts.Primary)="Y")) 


--- QUERY: qryAlternateContact ---
SELECT 2 FROM [tblAdvContacts] WHERE (((tblAdvContacts.ContactLevel)="Alternate")) 


--- QUERY: qryChronologicalComments ---
SELECT tblAdvertisers!Advertiser,tblAcctExecs.AcctExec,tblComments.CommentDate,tblComments.CommentTime,tblComments.Comment FROM [tblComments],[tblAdvertisers],[tblAcctExecs] ORDER BY tblComments.CommentDate


--- QUERY: qryCmbAcctExecID ---
SELECT tblAcctExecs.AcctExecID,tblAcctExecs.AcctExec FROM [tblAcctExecs] WHERE (((tblAcctExecs.Terminated)=0)) ORDER BY tblAcctExecs.AcctExec


--- QUERY: qryCmbAdvertiserOrLead ---
SELECT tblProductCategories.AdvertiserOrLead,tblProductCategories.AorLDescr FROM [tblProductCategories] WHERE (((tblProductCategories.AdvertiserOrLead)<>"All")) ORDER BY tblProductCategories.SortSeq


--- QUERY: qryCmbAE ---
SELECT tblAcctExecs.AcctExecID,tblAcctExecs.AcctExec FROM [tblAcctExecs] WHERE (((tblAcctExecs.Terminated)=0)) ORDER BY tblAcctExecs.AcctExec


--- QUERY: qryCmbAllAorP ---
SELECT tblProductCategories.AdvertiserOrLead,tblProductCategories.AorLDescr FROM [tblProductCategories] ORDER BY tblProductCategories.SortSeq


--- QUERY: qryCmbBusinessType ---
SELECT tblBusinessType.BusinessTypeID,tblBusinessType.BusinessType FROM [tblBusinessType] ORDER BY tblBusinessType.BusinessType


--- QUERY: qryCmbContactLevel ---
SELECT tblContactLevels.ContactLevel,tblContactLevels.SortSeq FROM [tblContactLevels] ORDER BY tblContactLevels.SortSeq


--- QUERY: qryCommentDateLatest ---
SELECT tblComments.AdvertiserID,Max(tblComments.CommentDate) FROM [tblComments] ORDER BY tblComments.AdvertiserID


--- QUERY: qryContactList ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Contact,tblAdvertisers.Phone,tblAcctExecs.AcctExec,tblAdvertisers.InitialContactDate,tblAdvertisers.LastContactDate,tblAdvertisers.Dead,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.AdvertiserID FROM [tblAcctExecs],[tblAdvertisers] WHERE tblAdvertisers.AdvertiserOrLead="L" ORDER BY tblAdvertisers.Advertiser


--- QUERY: qryContactLvlClient ---
SELECT "Client",1 FROM [tblAdvContacts] 


--- QUERY: qryContractType ---
SELECT tblContractType.ContractType FROM [tblContractType] ORDER BY tblContractType.SortID


--- QUERY: qryCreateTblAdvContactsAlt ---
SELECT tblAdvertisers.AdvertiserID,IIf([FirstBlank]=0,"",Right([tblAdvertisers]![AlternateContact],Len([tblAdvertisers]![AlternateContact])-[FirstBlank])),IIf([FirstBlank]=0,[tblAdvertisers]![AlternateContact],Left([tblAdvertisers]![AlternateContact],[FirstBlank]-1)),Null,Null,Null,tblAdvertisers.Email,tblAdvertisers.Phone,tblAdvertisers.PhExt,tblAdvertisers.Street,tblAdvertisers.Suite,tblAdvertisers.City,tblAdvertisers.ST,tblAdvertisers.ZIP,tblAdvertisers.Advertiser,"Alternate",2,InStr(1,[tblAdvertisers]![AlternateContact]," ",1),Null,Null FROM [tblAdvertisers] WHERE (((InStr(1,[tblAdvertisers]![AlternateContact]," ",1)) Is Not Null)) 


--- QUERY: qryCreateTblAdvContactsxxx ---
SELECT tblAdvertisers.AdvertiserID,IIf([FirstBlank]=0,"",Right([tblAdvertisers]![Contact],Len([tblAdvertisers]![Contact])-[FirstBlank])),IIf([FirstBlank]=0,[tblAdvertisers]![Contact],Left([tblAdvertisers]![Contact],[FirstBlank]-1)),Null,Null,[tblAdvertisers]![Title],tblAdvertisers.Email,[tblAdvertisers]![Phone],tblAdvertisers.PhExt,tblAdvertisers.Street,tblAdvertisers.Suite,tblAdvertisers.City,tblAdvertisers.ST,tblAdvertisers.ZIP,[tblAdvertisers]![Advertiser],"Primary",Null,Null,InStr(1,[tblAdvertisers]![Contact]," ",1) FROM [tblAdvertisers] WHERE (((InStr(1,[tblAdvertisers]![Contact]," ",1)) Is Not Null)) 


--- QUERY: qryDeleteAdvertiser ---
SELECT tblAdvertisers.*,tblAdvertisers.AdvertiserID FROM [tblAdvertisers] WHERE (((tblAdvertisers.AdvertiserID)=11107)) 


--- QUERY: QryGtoP ---
SELECT "P" FROM [tblAdvertisers] WHERE (((tblAdvertisers.AdvertiserOrLead)="G")) 


--- QUERY: qryNullAdvAltContacts ---
SELECT tblAdvertisers.AlternateContact,tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser FROM [tblAdvertisers] WHERE (((tblAdvertisers.AlternateContact) Is Null)) ORDER BY tblAdvertisers.Advertiser


--- QUERY: qryNullAdvContacts ---
SELECT tblAdvertisers.Contact,tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser FROM [tblAdvertisers] WHERE (((tblAdvertisers.Contact) Is Null)) ORDER BY tblAdvertisers.Advertiser


--- QUERY: qryPrefix ---
SELECT tblPrefix.Prefix FROM [tblPrefix] ORDER BY tblPrefix.SortSeq


--- QUERY: qryProspectList ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Contact,tblAdvertisers.Phone,tblAcctExecs.AcctExec,tblAdvertisers.InitialContactDate,tblAdvertisers.LastContactDate,tblAdvertisers.Dead,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.AdvertiserID FROM [tblAcctExecs],[tblAdvertisers] WHERE tblAdvertisers.AdvertiserOrLead="P" ORDER BY tblAdvertisers.Advertiser


--- QUERY: qryRptAdvertisers ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Contact,tblAcctExecs.AcctExec,tblAdvertisers.LastContactDate,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.InitialContactDate,tblAdvertisers.ContractExpires,tblAdvertisers.ContractType,qryCommentDateLatest.[Last Contact],tblAdvertisers.Temp FROM [tblAcctExecs],[tblAdvertisers],[qryCommentDateLatest] ORDER BY tblAdvertisers.Advertiser


--- QUERY: qrySfrmAdvContacts ---
SELECT tblAdvContacts.PrimarySeq,tblAdvContacts.ContactID,tblAdvContacts.AdvertiserID,tblAdvContacts.ContactLevelSeq,tblAdvContacts.LName,tblAdvContacts.FName,tblAdvContacts.Prefix,tblAdvContacts.Suffix,tblAdvContacts.CoTitle,tblAdvContacts.EMail,tblAdvContacts.Ph,tblAdvContacts.PhExt,tblAdvContacts.Street,tblAdvContacts.Suite,tblAdvContacts.City,tblAdvContacts.ST,tblAdvContacts.ZIP,tblAdvContacts.Organization,tblAdvContacts.ContactLevel,tblAdvContacts.PhCell,tblAdvContacts.PhFax,tblAdvContacts.Primary,tblAdvContacts.Website FROM [tblAdvContacts] ORDER BY tblAdvContacts.PrimarySeq


--- QUERY: qrySfrmComments ---
SELECT tblComments.CommentID,tblComments.AdvertiserID,tblComments.CommentDate,tblComments.CommentTime,tblComments.Comment,tblAcctExecs.AcctExec FROM [tblComments],[tblAcctExecs] WHERE (((tblComments.AdvertiserID)=Forms!frmAdvertisers!AdvertiserID)) ORDER BY tblComments.CommentDate


--- QUERY: qryStPostalCd ---
SELECT tblStPostalCd.ST FROM [tblStPostalCd] ORDER BY tblStPostalCd.ST


--- QUERY: qrySuffix ---
SELECT tblSuffix.Suffix FROM [tblSuffix] ORDER BY tblSuffix.SortSeq


--- QUERY: qryTestAdvSelection ---
SELECT tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,([qryAdvPrimaryContacts]![FName] & " " & [qryAdvPrimaryContacts]![LName]),tblAdvertisers.Street,tblAdvertisers.City,tblAdvertisers.St,tblAdvertisers.Zip,tblAdvertisers.Phone,tblAdvertisers.PhExt,tblAdvertisers.Email,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.ContractDate,tblAdvertisers.InitialContactDate,qryCommentDateLatest.[Last Contact],tblAdvertisers.Temp,tblAdvertisers.Active,tblBusinessType.BusinessType FROM [tblAcctExecs],[tblAdvertisers],[qryCommentDateLatest],[tblBusinessType],[qryAdvPrimaryContacts] ORDER BY tblAdvertisers.Advertiser


--- QUERY: Query1 ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Contact,tblAdvertisers.Phone,tblAcctExecs.AcctExec,tblAdvertisers.LastContactDate,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.AdvertiserID FROM [tblAcctExecs],[tblAdvertisers] WHERE tblAdvertisers.AdvertiserOrLead="A" And tblAdvertisers.Advertiser Like "bellai*" ORDER BY tblAdvertisers.Advertiser


--- QUERY: Query2 ---
SELECT tblAdvertisers.AcctExecID,tblAdvertisers.AdvertiserOrLead FROM [tblAdvertisers] WHERE (((tblAdvertisers.AcctExecID)=Forms!frmAdvertisers!cmbAcctExecID) And ((tblAdvertisers.AdvertiserOrLead)="L")) 


--- QUERY: Query3a ---
SELECT tblAdvertisers.AdvertiserID,tblAdvertisers.AcctExecID,tblAdvertisers.AdvertiserOrLead FROM [tblAdvertisers] WHERE (((tblAdvertisers.AdvertiserOrLead)="P")) ORDER BY tblAdvertisers.AcctExecID


--- QUERY: Query4 ---
SELECT tblPPAMaxQty.AdvertiserOrLead,tblPPAMaxQty.MaxQty FROM [tblPPAMaxQty] WHERE (((tblPPAMaxQty.AdvertiserOrLead)=[Forms]![frmAdvertisers]![cmbAdvertiserOrLead])) 


--- QUERY: updFillBlankInitialDate ---
SELECT #6/1/2006# FROM [tblAdvertisers] WHERE (((tblAdvertisers.InitialContactDate) Is Null)) 


--- QUERY: updLeadsToProspects ---
SELECT "P" FROM [tblAdvertisers] WHERE (((tblAdvertisers.AdvertiserOrLead)="L")) 


--- QUERY: updOpenProspectsToCold ---
SELECT "Cold" FROM [tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvertisers.AcctExecID)=11)) 


--- QUERY: ~sq_ffrmPPAMaxQty ---
SELECT DISTINCTROW  FROM [tblPPAMaxQty] 


--- QUERY: ~sq_ffrmProductCategories ---
SELECT DISTINCTROW  FROM [tblProductCategories] 


--- QUERY: ~sq_ffrmSuffix ---
SELECT DISTINCTROW  FROM [tblSuffix] 


--- QUERY: Find duplicates for tblAdvertisers ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Street,tblAdvertisers.Contact,tblAcctExecs.AcctExec FROM [tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvertisers.Advertiser) In (SELECT [Advertiser] FROM [tblAdvertisers] As Tmp GROUP BY [Advertiser] HAVING Count(*)>1 ))) ORDER BY tblAdvertisers.Advertiser


--- QUERY: qry_CONCAT_FullPop ---
SELECT DISTINCT  FROM [],[] 


--- QUERY: qry_Concat_StreetAndSuite ---
SELECT "tblAdvContacts",tblAdvContacts.ContactID,tblAdvContacts.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvContacts.Street,tblAdvContacts.Suite,[tblAdvContacts].[Street] & ', Suite ' & [tblAdvContacts].[Suite] FROM [tblAdvContacts],[tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvContacts.Street) Not Like '*' & [tblAdvContacts].[Suite] & '*') AND ((tblAdvContacts.Suite) Is Not Null)) 


--- QUERY: qry_Concat_StreetAndSuite_6 ---
SELECT 'tblAdvertisers','',tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,tblAcctExecs.AcctExec,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.Street,tblAdvertisers.Suite,[tblAdvertisers].[Street] & ',  ' & [tblAdvertisers].[Suite] FROM [tblAdvertisers],[tblAcctExecs] WHERE (((tblAdvertisers.Street) Not Like '*Suite*' And (tblAdvertisers.Street) Not Like '*ste*') AND ((tblAdvertisers.Suite) Like '*Suite*')) 


--- QUERY: qryAdvertisers ---
SELECT tblAdvertisers.AdvertiserID,tblAdvertisers.Advertiser,tblAdvertisers.Street,tblAdvertisers.Suite,tblAdvertisers.City,tblAdvertisers.ST,tblAdvertisers.ZIP,tblAdvertisers.Contact,tblAdvertisers.Title,tblAdvertisers.Phone,tblAdvertisers.PhExt,tblAdvertisers.Fax,tblAdvertisers.Email,tblAdvertisers.AlternateContact,tblAdvertisers.AcctExecID,tblAdvertisers.EntryDate,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.LastContactDate,tblAdvertisers.Comments,tblAdvertisers.InitialContactDate,tblAdvertisers.Dead,tblAdvertisers.Temp,tblAdvertisers.Active,tblAdvertisers.ContractExpires,tblAdvertisers.BusinessType,tblAdvertisers.ContractType,tblAdvertisers.Website FROM [tblAdvertisers] ORDER BY tblAdvertisers.Advertiser


--- QUERY: qryChronologicalCommentsTemplate ---
SELECT tblAdvertisers!Advertiser & " " & tblAdvertisers!Street,tblAcctExecs.AcctExec,tblComments.CommentDate,tblComments.CommentTime,tblComments.Comment FROM [tblComments],[tblAdvertisers],[tblAcctExecs] ORDER BY tblAdvertisers!Advertiser & " " & tblAdvertisers!Street


--- QUERY: qryCmdPrimaryContact ---
SELECT tblPrimaryContact.Primary,tblPrimaryContact.PrimarySeq FROM [tblPrimaryContact] ORDER BY tblPrimaryContact.PrimarySeq DESCENDING


--- QUERY: qryCreateTblAdvContacts ---
SELECT tblAdvertisers.AdvertiserID,IIf([FirstBlank]=0,"",Right([tblAdvertisers]![Contact],Len([tblAdvertisers]![Contact])-[FirstBlank])),IIf([FirstBlank]=0,[tblAdvertisers]![Contact],Left([tblAdvertisers]![Contact],[FirstBlank]-1)),Null,Null,[tblAdvertisers]![Title],tblAdvertisers.Email,[tblAdvertisers]![Phone],tblAdvertisers.PhExt,tblAdvertisers.Street,tblAdvertisers.Suite,tblAdvertisers.City,tblAdvertisers.ST,tblAdvertisers.ZIP,[tblAdvertisers]![Advertiser],"Primary",1,Null,Null,InStr(1,[tblAdvertisers]![Contact]," ",1) FROM [tblAdvertisers] WHERE (((InStr(1,[tblAdvertisers]![Contact]," ",1)) Is Not Null)) 


--- QUERY: qryListTemplate ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Contact,tblAdvertisers.Phone,tblAdvertisers.AdvertiserOrLead,tblAcctExecs.AcctExec,tblAdvertisers.InitialContactDate,qryCommentDateLatest.[Last Contact],tblAdvertisers.Temp,tblAdvertisers.Active,tblAdvertisers.AdvertiserID FROM [tblAcctExecs],[tblAdvertisers],[qryCommentDateLatest] 


--- QUERY: qryPrimaryContact ---
SELECT "X",1 FROM [tblAdvContacts] WHERE (((tblAdvContacts.ContactLevel)="Primary")) 


--- QUERY: qrySelectAdvertiser ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Street,tblAdvertisers.City,tblAdvertisers.ZIP FROM [tblAdvertisers] ORDER BY tblAdvertisers.Advertiser


--- QUERY: QryTest ---
SELECT tblAdvertisers.Advertiser,tblAdvertisers.Contact,tblAdvertisers.Phone,tblAcctExecs.AcctExec,tblAdvertisers.LastContactDate,tblAdvertisers.AdvertiserOrLead,tblAdvertisers.AdvertiserID FROM [tblAcctExecs],[tblAdvertisers] WHERE (((tblAdvertisers.Advertiser) Like Forms!frmAdvertiserAndContactLists!txtSelectAdvertiser+"*") And ((tblAdvertisers.AdvertiserOrLead)="A")) ORDER BY tblAdvertisers.Advertiser


--- QUERY: Query3 ---
SELECT Count(tblAdvertisers.AdvertiserID) FROM [tblAdvertisers] 


--- QUERY: Query5 ---
SELECT tblAdvContacts.ContactID,tblAdvContacts.AdvertiserID,tblAdvContacts.FName,tblAdvContacts.LName,tblAdvContacts.Primary,tblAdvContacts.PrimarySeq,tblAdvContacts.ContactLevel,tblAdvContacts.ContactLevelSeq FROM [tblAdvContacts] WHERE (((tblAdvContacts.AdvertiserID)=8318)) 


