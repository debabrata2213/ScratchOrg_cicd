// post-deploy-setup.apex
// Run after every metadata deploy to a fresh scratch org.
// Handles anything that can't be done via metadata alone.

System.debug('=== Post-deploy setup started ===');

// 1. Assign the permission set to the running user (typically the scratch org admin)
String permSetName = 'AccountContactAppAccess';
Id userId = UserInfo.getUserId();

List<PermissionSetAssignment> existing = [
    SELECT Id FROM PermissionSetAssignment
    WHERE AssigneeId = :userId
    AND PermissionSet.Name = :permSetName
    LIMIT 1
];

if (existing.isEmpty()) {
    PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permSetName LIMIT 1];
    insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id);
    System.debug('Permission set assigned: ' + permSetName);
} else {
    System.debug('Permission set already assigned, skipping.');
}

System.debug('=== Post-deploy setup complete ===');
