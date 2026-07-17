import { LightningElement, api } from 'lwc';
import { subscribe, unsubscribe } from 'lightning/empApi';
import getOrderTimeline from '@salesforce/apex/OrderService.getOrderTimeline';

export default class OrderTimeline extends LightningElement {
    @api recordId;
    timeLineItems = [];
    isLoading = false;
    subscription = {};

    stages = [
        {key: 'Draft', value: 'Order Placed'},
        {key: 'Confirmed', value: 'Payment Confirmed'},
        {key: 'Processing', value: 'Fulfilled'},
        {key: 'Shipped', value: 'Shipped'},
        {key: 'Delivered', value: 'Delivered'},
    ];

    buildTimelineItems(result){
        const currentStatus = result.order? result.order.Status__c : null;
        const historyMap = new Map();
        result.statusHistory?.forEach(history => {
            historyMap.set(history.NewValue, history.CreatedDate);
        });
        const currentStatusIndex = this.stages.findIndex(
            stage => stage.key === currentStatus
        );
        this.timeLineItems = this.stages.map((stage, index) => {
            const isCompleted = currentStatusIndex > index;
            const isCurrent = currentStatusIndex === index;
            const isPending = currentStatusIndex < index;
            let dotClass;
            let iconName;

            if (isCompleted) {
                dotClass = 'dot-completed';
                iconName = 'utility:check';
            } else if (isCurrent) {
                dotClass = 'dot-current';
                iconName = 'utility:refresh';
            } else {
                dotClass = 'dot-pending';
                iconName = 'utility:clock';
            }
            return{
                ...stage,
                isCompleted,
                isCurrent,
                isPending,
                timeStamp: historyMap.get(stage.key) || null,
                dotClass,
                iconName
            }
        });
    }

    async loadTimeline(){
        this.isLoading = true;
        try{
            console.log(this.recordId);
            const orderTimeline = await getOrderTimeline({orderId: this.recordId});
            console.log('Timeline: ' + JSON.stringify(orderTimeline));
            this.buildTimelineItems(orderTimeline);
            this.isLoading = false;
            console.log('Time line items' + JSON.stringify(this.timeLineItems));
        }catch(error){
            console.error(error);
        }
    }

    handlePlatformEvent(event){
        console.log('Inside platform event');
        console.log('Id: ', event.data.payload.Order_Id__c);
        if(event.data.payload.Order_Id__c === this.recordId){
            this.loadTimeline();
        }
    }

    connectedCallback() {
        console.log('Connected callback called');

        this.loadTimeline();

        const channel = '/event/Order_Status_Update__e';

        subscribe(channel, -1, (event) => {

            console.log(
                'EVENT RECEIVED:',
                JSON.stringify(event)
            );

            this.handlePlatformEvent(event);

        })
        .then(response => {

            console.log(
                'SUBSCRIPTION SUCCESS:',
                JSON.stringify(response)
            );

            this.subscription = response;

        })
        .catch(error => {

            console.error(
                'SUBSCRIPTION FAILED:',
                JSON.stringify(error)
            );

        });
    }

    disconnectedCallback(){
        // unsubscribe from platform event channel
    }


}