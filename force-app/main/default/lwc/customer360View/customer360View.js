import { LightningElement, api } from 'lwc';
import getCustomer360Data from '@salesforce/apex/Customer360Controller.getCustomer360Data';
import getRecentOrders from '@salesforce/apex/Customer360Controller.getRecentOrders';
import getOpenCases from '@salesforce/apex/Customer360Controller.getOpenCases';

export default class Customer360View extends LightningElement {
    @api recordId;

    accountData = null;
    loyaltyData = null;
    isLoading = false;

    activeTab = 'orders';
    orders = [];
    cases = [];
    isLoadingTabData = false;
    errorMessage;
    tabDataLoaded = {
        orders: false,
        cases: false
    }

    connectedCallback(){
        this.loadCustomer360();
    }

    async loadCustomer360(){
        this.isLoading = true;
        try{
            const customerData = await getCustomer360Data({accountId: this.recordId});
            console.log('C Data : ' + JSON.stringify(customerData));
            if(customerData.isSuccess){
                this.accountData = customerData.account;
                this.loyaltyData = customerData.loyalty;
                this.loadTabData('orders');
            }
        }catch(error){
            console.error(error);
            this.errorMessage = error;
        }finally{
            this.isLoading = false;
        }
    }

    async loadTabData(tabName){
        if(tabName === 'orders' && !(this.tabDataLoaded.orders)){
            try{
                this.isLoadingTabData = true;
                const ordersTabData = await getRecentOrders({accountId: this.recordId});
                this.orders = ordersTabData;
                this.tabDataLoaded.orders = true;
            }catch(error){
                console.error(error);
            }finally{
                this.isLoadingTabData = false;
            }
        }else if(tabName === 'cases' && !(this.tabDataLoaded.cases)){
            try{
                this.isLoadingTabData = true;
                const casesTabData = await getOpenCases({accountId : this.recordId});
                this.cases = casesTabData;
                this.tabDataLoaded.cases = true;
            }catch(error){
                console.error(error);
            }finally{
                this.isLoadingTabData = false;
            }
        }
    }

    get tierBadgeClass() {
        const tierClasses = {
            'Bronze'   : 'tier-badge tier-bronze',
            'Silver'   : 'tier-badge tier-silver',
            'Gold'     : 'tier-badge tier-gold',
            'Platinum' : 'tier-badge tier-platinum'
        };
        return tierClasses[this.loyaltyData?.Tier__c] || 'tier-badge tier-bronze';
    }

    get formattedTotalSpend(){
        return loyaltyData.Total_Spend__c ? '₹ ' + loyaltyData.Total_Spend__c : '₹ ' + 0;
    }

    get hasOrders(){
        return this.orders.length > 0;
    }

    get hasCases(){
        return this.cases.length > 0;
    }

    get customerLocation(){
        return this.accountData.BillingCity + ' , ' + this.accountData.BillingState;
    }

    handleTabChange(event){
        const activeTabName = event.target.value;
        this.activeTab = activeTabName;
        if(!this.tabDataLoaded.activeTabName){
            this.loadTabData(activeTabName);
        }
    }
}