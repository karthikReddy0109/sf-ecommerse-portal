import { LightningElement } from 'lwc';
import getOrders from '@salesforce/apex/OrderService.getOrders';
import getOrderLineItems from '@salesforce/apex/OrderService.getOrderLineItems';
import getValidNextStatuses from '@salesforce/apex/OrderService.getValidNextStatuses';
import updateOrderStatus from '@salesforce/apex/OrderService.updateOrderStatus';
import cancelOrder from '@salesforce/apex/OrderService.cancelOrder';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';

export default class OrderManagement extends LightningElement {
    selectedStatus = '';
    selectedPaymentStatus = '';
    fromDate = '';
    toDate = '';

    orders = [];
    isLoading = false;
    errorMessage;

    expandedOrderId = null;
    expandedOrderLineItems = [];
    isLoadingLineItems = false;

    selectedNextStatus = '';
    nextStatusOptions = [];

    statusOptions = [
        { label: 'All Statuses', value: '' },
        { label: 'Draft', value: 'Draft' },
        { label: 'Confirmed', value: 'Confirmed' },
        { label: 'Processing', value: 'Processing' },
        { label: 'Shipped', value: 'Shipped' },
        { label: 'Delivered', value: 'Delivered' },
        { label: 'Cancelled', value: 'Cancelled' }
    ];

    paymentStatusOptions = [
        { label: 'All Payment Statuses', value: '' },
        { label: 'Pending', value: 'Pending' },
        { label: 'Paid', value: 'Paid' },
        { label: 'Refunded', value: 'Refunded' }
    ];

    connectedCallback(){
        this.loadOrders();
    }

    async loadOrders(){
        this.isLoading = true;
        try{
            const orderList = await getOrders({status: this.selectedStatus, paymentStatus: this.selectedPaymentStatus, fromDate: this.fromDate, toDate: this.toDate});
            this.orders = orderList.map(order => ({
                ...order,
                isExpanded : false
            }));
            this.isLoading = false;
            console.log('Orders : ' + JSON.stringify(this.orders));
        }catch(error){
            this.errorMessage = error.body?.message || 'An error occurred';
            this.isLoading = false;
            console.error(error);
        }
    }

    handleStatusFilterChange(e){
        this.selectedStatus = e.detail.value;
        this.loadOrders();
    }

    handlePaymentStatusFilterChange(e){
        this.selectedPaymentStatus = e.detail.value;
        this.loadOrders();
    }

    handleNextStatusChange(e){
        this.selectedNextStatus = e.detail.value;
    }

    // async handleExpandRow(e){
    //     const orderId = e.currentTarget.dataset.id;
    //     console.log('Order Id : ' + orderId);
    //     if(orderId === this.expandedOrderId){
    //         this.expandedOrderId = null;
    //     }else{
    //         this.expandedOrderId = orderId;
    //         this.isLoadingLineItems = true;
    //         try{
    //             const orderLineItems = await getOrderLineItems({orderId : orderId});
    //             this.expandedOrderLineItems = orderLineItems;
    //             this.isLoadingLineItems = false;
    //             const currentOrder = this.orders.find(order => order.id === orderId);
    //             const validNextStatuses = await getValidNextStatuses({currentStatus : currentOrder.status});
    //             this.nextStatusOptions = validNextStatuses;
    //         }catch(error){
    //             console.error('Error from handleExpandRow');
    //             console.error('Complete Error : ' + error);
    //             console.error('JSON:', JSON.stringify(error));
    //             if (error.body) {
    //                 console.error('Message:', error.body.message);
    //                 console.error('Stack:', error.body.stackTrace);
    //             }
    //             this.isLoadingLineItems = false;
    //         }
    //     }
    // }
    handleExpandRow(event) {
        const orderId = event.currentTarget.dataset.id;
        
        this.orders = this.orders.map(order => {
            if(order.id === orderId) {
                return { ...order, isExpanded: !order.isExpanded };
            }
            // collapse all other rows
            return { ...order, isExpanded: false };
        });

        // find the clicked order
        const clickedOrder = this.orders.find(o => o.id === orderId);

        // only load line items if expanding, not collapsing
        if(clickedOrder.isExpanded) {
            this.loadLineItems(orderId, clickedOrder.status);
        } else {
            this.expandedOrderLineItems = [];
            this.nextStatusOptions = [];
        }
    }

    loadLineItems(orderId, currentStatus) {
        this.isLoadingLineItems = true;

        // load line items
        getOrderLineItems({ orderId: orderId })
            .then(result => {
                this.expandedOrderLineItems = result;
                this.isLoadingLineItems = false;
            })
            .catch(error => {
                this.errorMessage = error.body.message;
                this.isLoadingLineItems = false;
            });

        // load valid next statuses for this order's current status
        getValidNextStatuses({ currentStatus: currentStatus })
            .then(result => {
                this.nextStatusOptions = result;
            })
            .catch(error => {
                console.error(error);
            });
    }

    showSucessToastEvent(successMessage){
        const toastEvent = new ShowToastEvent({
            title: 'Success',
            message: successMessage,
            variant: 'success',
            mode: 'dismissable'
        });
        this.dispatchEvent(toastEvent);
    }

    showErrorToastEvent(errorMessage){
        const toastEvent = new ShowToastEvent({
            title: 'Error',
            message: errorMessage,
            variant: 'error',
            mode: 'dismissable'
        });
        this.dispatchEvent(toastEvent);
    }

    async handleUpdateStatus(e){
        const orderId = e.currentTarget.dataset.id;
        try{
            await updateOrderStatus({
                orderId: orderId, 
                newStatus: this.selectedNextStatus
            });
            this.showSucessToastEvent('Order status updated successfully');
            this.loadOrders(); // reload to reflect new status
        }catch(error){
            this.showErrorToastEvent(error.body?.message || 'Update failed');
        }
    }

    async handleCancelOrder(e){
        const orderId = e.currentTarget.dataset.id;
        try{
            const result = await cancelOrder({orderId: orderId});
            this.showSucessToastEvent('Order cancelled successfully');
            this.loadOrders();
        }catch(error){
            this.showErrorToastEvent(error);
        }
    }

    handleFromDateChange(e){
        this.fromDate = e.target.value;
        this.loadOrders();
    }

    handleToDateChange(e){
        this.toDate = e.target.value;
        this.loadOrders();
    }

    get hasExpandedLineItems(){
        return this.expandedOrderLineItems && this.expandedOrderLineItems.length > 0;
    }
}