on theSplit(theString, theDelimiter)
	-- save delimiters to restore old settings
	set oldDelims to AppleScript's text item delimiters
	-- set delimiters to delimiter to be used
	set AppleScript's text item delimiters to theDelimiter
	-- create the array
	set theArray to every text item of theString
	-- restore the old setting
	set AppleScript's text item delimiters to oldDelims
	-- return the result
	return theArray
end theSplit

tell application "Microsoft Outlook"
	(* set account *)
	set thisAccount to exchange account "Johnsonfit"
	
	try
		set ticketFolder to mail folder "Tickets" of thisAccount
	on error errmsg number errNum
		if errNum = -1728 then
			make new mail folder with properties {name:"Tickets"}
			set onTimeFolder to mail folder "Tickets" of thisAccount
		end if
	end try
	
	try
		set onTimeFolder to mail folder "OnTime" of thisAccount
	on error errmsg number errNum
		if errNum = -1728 then
			make new mail folder with properties {name:"OnTime"}
			set onTimeFolder to mail folder "OnTime" of thisAccount
		end if
	end try
	
	set onTimeSubjectList to {"OnTime Notification: Feature ID [#", "OnTime Notification: New Feature With Id [#"}
	set secondaryEmailDesignators to {"RE:", "re:", "Re:", "FW:", "Fw:", "FWD:", "Fwd:"}
	
	(*Replace with new messages when finished*)
	set theMessages to current messages
	
	set needleList to {{key:"ticketing", value:"ticketing.jhtna.com"}, {key:"onTime", value:"Axosoft.com"}}
	
	repeat with theMessage in theMessages
		set validEmail to false
		set processSubject to false
		set fromKnownDomain to false
		set processEmail to false
		set secondaryEmail to false
		set baseFolder to null
		set oldDelims to AppleScript's text item delimiters
		
		set theMessageBody to content of theMessage as text
		set theSubject to the subject of theMessage
		set theSender to sender of theMessage
		set theSenderAddress to address of theSender
		set theSenderAddressList to my theSplit(theSenderAddress, "@")
		set theSentDomain to item 2 of theSenderAddressList
		
		
		repeat with needle in needleList
			if theSentDomain = value of needle then
				set fromKnownDomain to true
				set processType to key of needle
				set processEmail to true
			end if
		end repeat
		
		if fromKnownDomain is false then
			(*Not from known sender but could be a fwd: or re: which relates to a ticket or ontime #*)
			repeat with secondaryEmailDesignator in secondaryEmailDesignators
				if theSubject contains secondaryEmailDesignator then
					(*Check if the domain is in the secondary message body. May not be the best way but oh well*)
					repeat with needle in needleList
						if theMessageBody contains value of needle then
							(*Need to do some more work to process these before we activate it*)
							(*Need to implement logic so that we know what type of email we are dealing with here, can't base on address and can't determine which specific needle we are on*)
							set processType to key of needle
							set processEmail to true
						end if
					end repeat
				end if
			end repeat
		end if
		
		(*Must have processEmail explicitally set to true to process the email*)
		if processEmail = true then
			(*Process if detected as a ticket email*)
			if processType = "ticketing" then
				set baseFolder to ticketFolder
				(*Determine type of email*)
				if theSubject contains "Ticket #" then
					(*Get the ticket number from email subject*)
					(*split subject by ' ' character add to list*)
					set subjectList to my theSplit(theSubject, " ")
					set searchFolder to item 1 of subjectList & " " & item 2 of subjectList
					set validEmail to true
				else
					(*Pull ticket number from the ticketing url number*)
					(*This should still theoretically work for Ticketing*)
					set AppleScript's text item delimiters to "<a href=\"http://ticketing.jhtna.com/ticket/detail/"
					try
						set theParsedMessageBody to text item 2 of theMessageBody
					on error errmsg number errNum
						log "Unknown Ticketing Email"
						set AppleScript's text item delimiters to oldDelims
						exit repeat
					end try
					set AppleScript's text item delimiters to "\">"
					try
						set theParsedMessageBody to text item 1 of theParsedMessageBody as number
						set searchFolder to "Ticket #" & theParsedMessageBody
						set AppleScript's text item delimiters to oldDelims
						set validEmail to true
					on error errmsg
						log errmsg
						set AppleScript's text item delimiters to oldDelims
					end try
					(*End type determination*)
				end if
				
				
				(*Process the body for the description text*)
				set AppleScript's text item delimiters to "The ticket &quot;"
				if theMessageBody contains "The ticket: &quot;" then
					set AppleScript's text item delimiters to "The ticket: &quot;"
				end if
				try
					set theParsedMessageBody to text item 2 of theMessageBody
				on error errmsg
					log "Unknown Ticket Email"
					exit repeat
				end try
				set AppleScript's text item delimiters to "&quot; has"
				try
					set theParsedMessageBody to text item 1 of theParsedMessageBody
					set searchFolder to searchFolder & " - " & theParsedMessageBody
					set AppleScript's text item delimiters to oldDelims
					set validEmail to true
				on error errmsg
					set AppleScript's text item delimiters to oldDelims
					log errmsg
				end try
				(*End processing body for description text*)
				
				(*Process if detected as onTime email*)
			else if processType = "onTime" then
				set baseFolder to onTimeFolder
				repeat with onTimeSubject in onTimeSubjectList
					if theSubject contains onTimeSubject then
						set processSubject to true
						exit repeat
					end if
				end repeat
				if processSubject is true then
					(*Get the ticket number from email subject*)
					(*split apart the subject to gather the OnTime number*)
					(*split subject by ' ' character add to list*)
					set oldDelims to AppleScript's text item delimiters
					repeat with onTimeSubjet in onTimeSubjectList
						if theSubject contains onTimeSubject then
							set AppleScript's text item delimiters to onTimeSubject
							exit repeat
						end if
					end repeat
					set theSubject to text item 2 of theSubject
					set AppleScript's text item delimiters to "]"
					try
						set theSubject to text item 1 of theSubject as number
					on error errmsg
						log errmsg
						set AppleScript's text item delimiters to oldDelims
						exit repeat
					end try
					set searchFolder to "OnTime #" & theSubject
					set AppleScript's text item delimiters to oldDelims
					set validEmail to true
				else
					(*Process OnTime body*)
					(********************)
					set oldDelims to AppleScript's text item delimiters
					set AppleScript's text item delimiters to "OnTime Notification: Feature ID [#"
					try
						set theParsedMessageBody to text item 2 of theMessageBody
					on error errmsg
						log "Unknown OnTime Email"
						exit repeat
					end try
					set AppleScript's text item delimiters to "]"
					try
						set theParsedMessageBody to text item 1 of theParsedMessageBody as number
						set searchFolder to "OnTime #" & theParsedMessageBody
						set AppleScript's text item delimiters to oldDelims
					on error errmsg
						set AppleScript's text item delimiters to oldDelims
						log errmsg
					end try
					(*******************)
					log "Processed Secondary Email"
				end if
				(*Process the body for the description text*)
				set AppleScript's text item delimiters to "<span style=\"color: #444;\">| "
				try
					set theParsedMessageBody to text item 2 of theMessageBody
				on error errmsg
					log "Unknown OnTime Email"
					exit repeat
				end try
				set AppleScript's text item delimiters to "</span></b>"
				try
					set theParsedMessageBody to text item 1 of theParsedMessageBody
					set searchFolder to searchFolder & " - " & theParsedMessageBody
					set AppleScript's text item delimiters to oldDelims
					set validEmail to true
				on error errmsg
					set AppleScript's text item delimiters to oldDelims
					log errmsg
				end try
				(*End processing body for description text*)
			else
				(*Script can't process this email*)
				log "Unknown Email"
			end if
			
			(*will move the email, validEmail but explicitally be set to true*)
			if validEmail is true then
				set baseFolderName to name of baseFolder
				try
					set targetFolder to mail folder searchFolder of folder baseFolderName of thisAccount
				on error errmsg number errNum
					if errNum is -1728 then
						make new mail folder at baseFolder with properties {name:searchFolder}
						set targetFolder to mail folder searchFolder of folder baseFolderName of thisAccount
					end if
				end try
				
				move theMessage to targetFolder
			end if
		end if
	end repeat
end tell