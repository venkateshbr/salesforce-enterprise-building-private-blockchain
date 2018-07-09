/*Copyright (c) 2018, Daniel Appleman

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, 
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation 
and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors 
may be used to endorse or promote products derived from this software without 
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND 
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF 
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
public without sharing class LedgerSupport {
    
    List<Ledger_Entry__c> entries;
    Ledger_Entry__c firstEntry;

    @TestVisible private static Boolean AllowUpdateTriggers = false;
    
    public static Boolean allowUpdates()
    {
        return Test.isRunningTest() && AllowUpdateTriggers;
    }
    
    public LedgerSupport(List<Ledger_Entry__c> currentEntries) {
        entries = currentEntries;
    }

    private void getLock()
    {
        List<Ledger_Entry__c> first = [Select ID from Ledger_Entry__c where Sequence__c = 0 for update];
        if(first.size()==1) firstEntry = first[0];
        if(first.size()>1) setRecordErrors('Blockchain is invalid'); // Should never happen
    }

   // Add errors to each record entry
    private void setRecordErrors(String errorMessage)
    {
        for(Ledger_Entry__c entry: entries) 
            {
                entry.addError(errorMessage);
            }
    }
    
    // Calculate the block hash from the transaction hash and prior block hash
    private static String calculateBlockHash(Ledger_Entry__c entry)
    {
        String source = entry.Transaction_Hash__c;
        if(entry.Prior_Block_Hash__c !=null ) source+= entry.Prior_Block_Hash__c;
        source+= String.valueOf((long)entry.Sequence__c);
        Blob b = Blob.valueOf(source);
        Blob hash = Crypto.generateDigest('SHA-256', b);
        String hashString = EncodingUtil.base64Encode(hash);
        return hashString;
    }

    // Set the blockchain fields for the current entry
    private void processBlockInsertion(Ledger_Entry__c entry, Decimal sequence, String priorBlockHash)
    {
        LedgerTransaction t = new LedgerTransaction(entry);
        t.SetTransactionHash();
        if(entry.Transaction_Hash__c == null) return;
        entry.Prior_Block_Hash__c = priorBlockHash;
        entry.Sequence__c = sequence;
        entry.Block_Hash__c = calculateBlockHash(entry);
    }

    // Called by OnInsertLedgerEntry durin before trigger
    public void processBlockInsertions()
    {
        try 
        {
            getLock();  // Get exclusive lock on the chain
        }
        catch(Exception ex)
        {
            setRecordErrors('Unable to obtain access to the Blockchain at this time, please try again later');
            return;
        }
        
        Ledger_Entry__c lastEntry = null;

        if(firstEntry!=null)
        {
            lastEntry = [Select ID, Block_Hash__c, Prior_Block_Hash__c, Transaction_Hash__c, Sequence__c 
                                        from Ledger_Entry__c Order By Sequence__c Desc Limit 1];
            // Validate the entry
            if(LastEntry.Block_Hash__c != calculateBlockHash(lastEntry))
            {
                setRecordErrors('Blockchain is invalid');
                return;
            }
        }

        // Now process the records in order
        for(Ledger_Entry__c entry: entries)
        {
            LedgerTransaction t = new LedgerTransaction(entry);
            if(lastEntry == null) processBlockInsertion(entry, 0, null);
            else processBlockInsertion(entry, lastEntry.Sequence__c + 1, lastEntry.Block_Hash__c);
            if(entry.Block_Hash__c == null) 
            {
                setRecordErrors('Attempt to insert an invalid block');
                return;
            }
            lastEntry = entry;
        }

        // Add insert notification here? (via async call, of course)

    }

    // Validate a block against the prior block
    // Note - prior block's Block_Hash__c field is assumed to have been validated already
    public static Boolean validateBlockHash(Ledger_Entry__c currentBlock, Ledger_Entry__c priorBlock)
    {
        // Check the sequence
        if(priorBlock!=null && currentBlock.Sequence__c != priorBlock.Sequence__c + 1) return false;

        // Check the transaction hash
        LedgerTransaction t = new LedgerTransaction(currentBlock);
        if(!t.isTransactionHashValid()) return false;

        // Check the prior block hash
        if(priorBlock!=null && currentBlock.Prior_Block_Hash__c != priorBlock.Block_Hash__c) return false; 

        // Make sure first block has no prior block
        if(priorBlock==null && currentBlock.Prior_Block_Hash__c !=null) return false;

        // Check the current block hash
        if(currentBlock.Block_Hash__c != calculateBlockHash(currentBlock)) return false;

        return true;
    }

    // Validates the list - returns the sequence # of the first failed block, or -1 on success
    public Decimal validateOrderedBlockList()
    {
        // Getting a lock here is optional - remove this if you run into trouble with locks while validations are occurring
        try 
        {
            getLock();  // Get exclusive lock on the chain
        }
        catch(Exception ex)
        {
           return 0;    // Flag root block as an error
        }

        // Get the previous block if one exists
        Ledger_Entry__c priorBlock = null;
        if(entries[0].Sequence__c != 0 )
            priorBlock = [Select ID, Block_Hash__c, Prior_Block_Hash__c, Sequence__c 
                            from Ledger_Entry__c 
                            where Sequence__c = :entries[0].Sequence__c -1];
 
        for(Ledger_Entry__c entry: entries)
        {
            Boolean validationResult = validateBlockHash(entry, priorBlock);
            if(!validationResult) return entry.Sequence__c;
            priorBlock = entry;
        }
        return -1;
    }


}
