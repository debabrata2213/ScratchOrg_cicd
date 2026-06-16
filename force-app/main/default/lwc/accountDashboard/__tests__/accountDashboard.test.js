import { createElement } from 'lwc';
import AccountDashboard from 'c/accountDashboard';
import getAccountsWithContacts from '@salesforce/apex/AccountService.getAccountsWithContacts';
import updateAccountTier from '@salesforce/apex/AccountService.updateAccountTier';

jest.mock('@salesforce/apex/AccountService.getAccountsWithContacts', () => ({
    default: jest.fn()
}), { virtual: true });

jest.mock('@salesforce/apex/AccountService.updateAccountTier', () => ({
    default: jest.fn()
}), { virtual: true });

const MOCK_ACCOUNTS = [
    {
        Id: '001000000000001',
        Name: 'Acme Corp',
        AccountTier__c: 'Gold',
        Industry: 'Technology',
        Phone: '5550001111',
        Contacts: [
            { Id: '003000000000001', FirstName: 'Alice', LastName: 'Smith',
              Email: 'alice@acme.com', PriorityScore__c: 15 }
        ]
    },
    {
        Id: '001000000000002',
        Name: 'Globex Inc',
        AccountTier__c: 'Bronze',
        Industry: 'Finance',
        Phone: null,
        Contacts: []
    }
];

describe('c-account-dashboard', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders a card for each account', async () => {
        getAccountsWithContacts.default.mockResolvedValue(MOCK_ACCOUNTS);
        const el = createElement('c-account-dashboard', { is: AccountDashboard });
        document.body.appendChild(el);
        await Promise.resolve();
        await Promise.resolve();

        const cards = el.shadowRoot.querySelectorAll('.account-card');
        expect(cards.length).toBe(2);
    });

    it('shows account names', async () => {
        getAccountsWithContacts.default.mockResolvedValue(MOCK_ACCOUNTS);
        const el = createElement('c-account-dashboard', { is: AccountDashboard });
        document.body.appendChild(el);
        await Promise.resolve();
        await Promise.resolve();

        const text = el.shadowRoot.textContent;
        expect(text).toContain('Acme Corp');
        expect(text).toContain('Globex Inc');
    });

    it('shows contact priority score', async () => {
        getAccountsWithContacts.default.mockResolvedValue(MOCK_ACCOUNTS);
        const el = createElement('c-account-dashboard', { is: AccountDashboard });
        document.body.appendChild(el);
        await Promise.resolve();
        await Promise.resolve();

        const text = el.shadowRoot.textContent;
        expect(text).toContain('Score: 15');
    });

    it('shows error message on API failure', async () => {
        getAccountsWithContacts.default.mockRejectedValue({
            body: { message: 'Server error' }
        });
        const el = createElement('c-account-dashboard', { is: AccountDashboard });
        document.body.appendChild(el);
        await Promise.resolve();
        await Promise.resolve();

        const errorEl = el.shadowRoot.querySelector('.slds-text-color_error');
        expect(errorEl).not.toBeNull();
        expect(errorEl.textContent).toBe('Server error');
    });
});
