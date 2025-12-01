// Account Balances Widget - Multi-broker account balances
"use client";

import { useState, useEffect } from "react";
import { BaseWidget } from "./BaseWidget";

interface AccountBalance {
  broker: string;
  account_name: string;
  balance: number;
  currency: string;
  available_balance?: number;
  pending_withdrawals?: number;
  last_updated: string;
  status: "connected" | "disconnected" | "error";
}

export function AccountBalancesWidget() {
  const [accounts, setAccounts] = useState<AccountBalance[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function loadBalances() {
      try {
        setLoading(true);
        // TODO: Replace with actual multi-broker API endpoint
        // For now, fetch Kalshi account and add placeholders
        const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:3000";
        const userId = "default"; // TODO: Get from auth context
        
        try {
          const kalshiRes = await fetch(`${baseUrl}/kalshi/users/${userId}/account`);
          if (kalshiRes.ok) {
            const kalshiData = await kalshiRes.json();
            const accountsList: AccountBalance[] = [
              {
                broker: "Kalshi",
                account_name: "Main Account",
                balance: parseFloat(kalshiData.balance.balance.toString()),
                currency: kalshiData.balance.currency || "USD",
                available_balance: parseFloat(kalshiData.balance.available_balance.toString()),
                pending_withdrawals: parseFloat(kalshiData.balance.pending_withdrawals.toString()),
                last_updated: kalshiData.fetched_at || new Date().toISOString(),
                status: "connected",
              },
              // Placeholder accounts
              {
                broker: "Robinhood",
                account_name: "Trading Account",
                balance: 0,
                currency: "USD",
                last_updated: new Date().toISOString(),
                status: "disconnected",
              },
              {
                broker: "Schwab",
                account_name: "Investment Account",
                balance: 0,
                currency: "USD",
                last_updated: new Date().toISOString(),
                status: "disconnected",
              },
              {
                broker: "Coinbase",
                account_name: "Crypto Wallet",
                balance: 0,
                currency: "USD",
                last_updated: new Date().toISOString(),
                status: "disconnected",
              },
            ];
            setAccounts(accountsList);
          } else {
            throw new Error("Failed to fetch Kalshi account");
          }
        } catch (err) {
          // If Kalshi fails, show placeholder accounts
          setAccounts([
            {
              broker: "Kalshi",
              account_name: "Main Account",
              balance: 0,
              currency: "USD",
              last_updated: new Date().toISOString(),
              status: "disconnected",
            },
            {
              broker: "Robinhood",
              account_name: "Trading Account",
              balance: 0,
              currency: "USD",
              last_updated: new Date().toISOString(),
              status: "disconnected",
            },
            {
              broker: "Schwab",
              account_name: "Investment Account",
              balance: 0,
              currency: "USD",
              last_updated: new Date().toISOString(),
              status: "disconnected",
            },
            {
              broker: "Coinbase",
              account_name: "Crypto Wallet",
              balance: 0,
              currency: "USD",
              last_updated: new Date().toISOString(),
              status: "disconnected",
            },
          ]);
        }
        setError(null);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load account balances");
      } finally {
        setLoading(false);
      }
    }
    loadBalances();
  }, []);

  const formatBalance = (balance: number, currency: string) => {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: currency,
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(balance);
  };

  const formatTime = (isoString: string) => {
    const date = new Date(isoString);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);

    if (diffMins < 5) return "Just now";
    if (diffMins < 60) return `${diffMins}m ago`;
    return date.toLocaleTimeString();
  };

  const getBrokerIcon = (broker: string) => {
    const icons: Record<string, string> = {
      Kalshi: "K",
      Robinhood: "R",
      Schwab: "S",
      Coinbase: "C",
    };
    return icons[broker] || "•";
  };

  const totalBalance = accounts.reduce((sum, acc) => sum + acc.balance, 0);

  return (
    <BaseWidget
      title="Account Balances"
      loading={loading}
      error={error}
      actions={
        <button className="markets-widget-action-btn" title="Link account">
          +
        </button>
      }
    >
      <div className="markets-accounts">
        {accounts.length > 0 && (
          <div className="markets-accounts-total">
            <span className="markets-accounts-total-label">Total Balance</span>
            <span className="markets-accounts-total-value">
              {formatBalance(totalBalance, "USD")}
            </span>
          </div>
        )}
        <div className="markets-accounts-list">
          {accounts.map((account, idx) => (
            <div
              key={idx}
              className={`markets-account-item markets-account-item-${account.status}`}
            >
              <div className="markets-account-header">
                <div className="markets-account-broker">
                  <span className="markets-account-icon">{getBrokerIcon(account.broker)}</span>
                  <div className="markets-account-info">
                    <span className="markets-account-name">{account.broker}</span>
                    <span className="markets-account-subname">{account.account_name}</span>
                  </div>
                </div>
                <span className={`markets-account-status markets-account-status-${account.status}`}>
                  {account.status === "connected" ? "●" : "○"}
                </span>
              </div>
              <div className="markets-account-balance">
                {account.status === "connected" ? (
                  <>
                    <span className="markets-account-balance-value">
                      {formatBalance(account.balance, account.currency)}
                    </span>
                    {account.available_balance !== undefined && (
                      <span className="markets-account-balance-available">
                        Available: {formatBalance(account.available_balance, account.currency)}
                      </span>
                    )}
                    <span className="markets-account-updated">
                      Updated {formatTime(account.last_updated)}
                    </span>
                  </>
                ) : (
                  <button className="markets-account-connect-btn">Connect Account</button>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>
    </BaseWidget>
  );
}

