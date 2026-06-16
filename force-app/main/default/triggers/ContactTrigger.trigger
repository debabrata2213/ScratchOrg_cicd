trigger ContactTrigger on Contact (after insert, after update, after delete) {
    Set<Id> accountIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate) {
        for (Contact c : Trigger.new) {
            if (c.AccountId != null) accountIds.add(c.AccountId);
        }
    }

    if (Trigger.isDelete) {
        for (Contact c : Trigger.old) {
            if (c.AccountId != null) accountIds.add(c.AccountId);
        }
    }

    if (!accountIds.isEmpty()) {
        AccountService.recalculatePriorityScores(accountIds);
    }
}
