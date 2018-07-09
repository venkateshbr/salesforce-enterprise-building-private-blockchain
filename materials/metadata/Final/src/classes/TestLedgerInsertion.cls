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

@istest
public class TestLedgerInsertion {
    
    @istest
    public static void TestLedgerInsertion() {
        List<Ledger_Entry__c> entries = new List<Ledger_Entry__c>();
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp1', Opportunity_Amount__c = 5));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp2', Opportunity_Amount__c = 10));
        Test.startTest();
        insert entries;
        Test.stopTest();

        List<Ledger_Entry__c> results = [Select ID, Block_Hash__c, Prior_Block_Hash__c, 
                                        Sequence__c, Transaction_Hash__c, Transaction_Field_List__c,
                                        Transaction_Date__c,
                                        Opportunity_Name__c, Opportunity_Amount__c 
                                        from Ledger_Entry__c Order By Sequence__c Asc];
        System.assertEquals(0, results[0].sequence__c);
        System.assertEquals(1, results[1].sequence__c);
        System.assert(results[0].Block_Hash__c == results[1].Prior_Block_Hash__c);
        System.assertEquals(null, results[0].Prior_Block_Hash__c);
        for(Ledger_Entry__c entry: results)
        {
            system.assertNotEquals(null, entry.Block_Hash__c);
            system.assertNotEquals(null, entry.Transaction_Hash__c);
        }
        System.assert(LedgerSupport.validateBlockHash(results[1], results[0]));
    }

    @istest
    public static void TestSubsequentLedgerInsertion() {
        List<Ledger_Entry__c> entries = new List<Ledger_Entry__c>();
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp1', Opportunity_Amount__c = 5));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp2', Opportunity_Amount__c = 10));
        insert entries;
        Test.startTest();
        entries.clear();
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp3', Opportunity_Amount__c = 15));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp4', Opportunity_Amount__c = 20));
        insert entries;
        Test.stopTest();

        List<Ledger_Entry__c> results = [Select ID, Block_Hash__c, Prior_Block_Hash__c, 
                                        Sequence__c, Transaction_Hash__c, Transaction_Field_List__c,
                                        Transaction_Date__c,
                                        Opportunity_Name__c, Opportunity_Amount__c 
                                        from Ledger_Entry__c Order By Sequence__c Asc];
        System.assertEquals(4, results.size());
        LedgerSupport ls = new LedgerSupport(results);
        System.assertEquals(-1, ls.validateOrderedBlockList());
    }

// Test corrupted last block
@istest
    public static void TestSubsequentLedgerInsertionFailure() {
        List<Ledger_Entry__c> entries = new List<Ledger_Entry__c>();
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp1', Opportunity_Amount__c = 5));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp2', Opportunity_Amount__c = 10));
        insert entries;
        LedgerSupport.AllowUpdateTriggers = true;
        Ledger_Entry__c badEntry = [Select ID, Prior_Block_Hash__c from Ledger_Entry__c where Opportunity_Name__c = 'opp2'];
        badEntry.Prior_Block_Hash__c = 'badhash';
        update badEntry;
        Test.startTest();
        entries.clear();
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp3', Opportunity_Amount__c = 15));
        entries.add(new Ledger_Entry__c(Opportunity_Name__c = 'opp4', Opportunity_Amount__c = 20));
        Boolean errorFound = false;
        try
        {
            insert entries;
        }
        catch(Exception ex)
        {
            errorFound = true;
        }
        Test.stopTest();

        system.assert(errorFound);
        List<Ledger_Entry__c> results = [Select ID, Block_Hash__c, Prior_Block_Hash__c, 
                                        Sequence__c, Transaction_Hash__c, Transaction_Field_List__c,
                                        Transaction_Date__c,
                                        Opportunity_Name__c, Opportunity_Amount__c 
                                        from Ledger_Entry__c Order By Sequence__c Asc];
        
        System.assertEquals(2, results.size()); // 2nd batch wasn't added
        LedgerSupport ls = new LedgerSupport(results);
        // And it should be a failure
        System.assertEquals(1, ls.validateOrderedBlockList());
    }

}
