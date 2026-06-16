import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAccountsWithContacts from '@salesforce/apex/AccountService.getAccountsWithContacts';
import updateAccountTier from '@salesforce/apex/AccountService.updateAccountTier';

export default class AccountDashboard extends LightningElement {
    @track accounts = [];
    @track isLoading = true;
    @track error;

    tierOptions = [
        { label: 'Gold',   value: 'Gold' },
        { label: 'Silver', value: 'Silver' },
        { label: 'Bronze', value: 'Bronze' }
    ];

    connectedCallback() {
        this.loadAccounts();
    }

    loadAccounts() {
        this.isLoading = true;
        getAccountsWithContacts()
            .then(data => {
                this.accounts = data.map(acc => ({
                    ...acc,
                    Contacts:  acc.Contacts || [],
                    tierClass: this.getTierClass(acc.AccountTier__c)
                }));
                this.error = undefined;
            })
            .catch(err => {
                this.error = err.body?.message || 'Unknown error loading accounts.';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleTierChange(event) {
        const accountId = event.target.dataset.accountId;
        const tier      = event.detail.value;

        updateAccountTier({ accountId, tier })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Success',
                    message: 'Account tier updated.',
                    variant: 'success'
                }));
                this.loadAccounts();
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({
                    title:   'Error',
                    message: err.body?.message || 'Failed to update tier.',
                    variant: 'error'
                }));
            });
    }

    getTierClass(tier) {
        const map = { Gold: 'tier-gold', Silver: 'tier-silver', Bronze: 'tier-bronze' };
        return map[tier] || '';
    }
}
