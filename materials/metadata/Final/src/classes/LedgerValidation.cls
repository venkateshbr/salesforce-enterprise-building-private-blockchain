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

public without sharing class LedgerValidation implements Database.Batchable<sObject>, Database.Stateful
{

    private Decimal failedBlock;

    private static String getQueryString(Boolean allRecords)
    {
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Ledger_Entry__c.fields.getMap();
        String queryString = 'Select ';
        queryString += String.Join(new List<String>(fieldMap.keyset()),',');
        queryString += ' From Ledger_Entry__c ';
        if(allRecords) queryString+= ' Order By Sequence__c Asc';
        return queryString;
    }


    public Database.QueryLocator start(Database.BatchableContext bc)
    {
        failedBlock = -1;
        // Query for all fields
        // Alternatively, could requery in each execute, but this should be fine
        return Database.getQueryLocator(getQueryString(true));
    }

    @TestVisible public static decimal BlockChainErrorRecord = -1;

    public void execute(Database.BatchableContext bc, List<Ledger_Entry__c> scope)
    {
        LedgerSupport ls = new LedgerSupport(scope);
        Decimal result = ls.validateOrderedBlockList();
        if(result!= -1)
        {
            system.debug('Block chain did not validate on batch ' + result);
            failedBlock = result;
            BlockChainErrorRecord = failedBlock;
            reportValidationStatus(failedBlock);
            system.abortJob(bc.getJobId());
        }
    }


    public void finish(Database.BatchableContext bc)
    {
        reportValidationStatus(failedBlock);
    }

    public static void reportValidationStatus(Decimal validationResult)
    {
        // Example of reporting validation results
        List<CollaborationGroup> cgs = [Select ID from CollaborationGroup where Name = 'Ledger Validation'];
        if(cgs.size()==0) return;
        FeedItem fd = new FeedItem(ParentID = cgs[0].id);

        if(validationResult >=0)
        {
            fd.Body = 'Ledger Validation failed at Sequence ' + 
                        String.valueOf(validationResult);
        }
        else
        {
            fd.Body = 'Ledger Validation complete';
        }
        insert fd;
    }
    
    // Test a single block by hash value to see if it is valid
    public static Boolean validateOneBlockByHash(String hashValue)
    {
        String queryString = getQueryString(false);
        List<Ledger_Entry__c> entries = Database.query(queryString + ' where Transaction_Hash__c = :hashValue');
        if(entries.size()==0) return false;
        LedgerSupport ls = new LedgerSupport(entries);
        return(ls.validateOrderedBlockList()== -1);
    }

}
